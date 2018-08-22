# Withdrawal assumptions:
# - user withdraws amount without specifying exact TokenVotes from which amount
# will be withdrawn. It is up to plugin to decide on optimal funds souce. User can
# withdraw sum of all available amounts in one go.
# - user can withdraw part of the funds, including multiple withdraws of the
# exact same amount to same output address(es).
# - user can cancel withdrawal before it has been fulfilled (i.e. before status
# changes to 'pending').
# - plugin has to effectively batch withdrawals to incur minimal fees, including
# merger of multiple withdrawals for the same token (incl. different users) in one tx.
# - loss of information regarding withdrawals (e.g. token_withdrawals table corruption or
# deletion) must not incur double withdrawals.
#
# Withdrawal statuses:
# - requested - requested by user, tx not prepared, user can still cancel.
# Withdrawal contains only token_type, amount and destination address, without
# specification of source TokenVotes. Requested withdrawal is not reflected in
# TokenPendingOutflows nor TokenPayouts.
# - pending - tx prepared and waiting to be sent or has already been sent, tx
# has less than min_conf confirmations, user cannot cancel withdrawal.
# Withdrawal is reflected in TokenTransactions, TokenPendingOutflows and TokenPayouts.
# - processed - tx has been sent and has at least min_conf confirmations.
# TokenPendingOutflows for processed withdrawal is canceled as it is
# already reflected in TokenVotes#amount_conf.
# - rejected - at the time of processing requested withdrawal, not ehough funds
# are available (e.g. because completed issue has been reverted to uncompleted)

class TokenWithdrawal < ActiveRecord::Base
  belongs_to :payee, class_name: 'User'
  belongs_to :token_type
  belongs_to :token_transaction

  validates :payee, :token_type, presence: true, associated: true
  validates :token_transaction, associated: true
  validates :amount, numericality: { greater_than: 0 }
  validates :amount, numericality:
    { less_than_or_equal_to: :amount_withdrawable, if: :requested? }
  validates :address, presence: true
  validates :is_rejected, inclusion: [true, false]

  after_initialize :set_defaults

  scope :requested, -> { where(is_rejected: false, token_transaction: nil) }
  scope :rejected, -> { where(is_rejected: true) }
  scope :pending, -> { 
    joins(:token_transaction).where(token_transactions: {is_processed: false})
  }
  scope :processed, -> {
    joins(:token_transaction).where(token_transactions: {is_processed: true})
  }

  scope :token, ->(token_t) { where(token_type: token_t) }

  def reject!
    self.is_rejected = true
    self.save!
  end

  def requested?
    not self.is_rejected && self.token_transaction.nil?
  end

  def rejected?
    self.is_rejected
  end

  def amount_withdrawable
    total = BigDecimal(0)
    TokenWithdrawal.transaction do
      total += self.payee.token_payouts.token(self.token_type).sum(:amount)
      total += self.payee.token_votes.token(self.token_type).expired.sum(:amount_conf)
      total -= self.payee.token_votes.token(self.token_type).expired
        .joins(:token_pending_outflows).sum(:amount)
      total -= self.payee.token_withdrawals.token(self.token_type).requested
        .where.not(id: self.id).sum(:amount)
    end
    total
  end

  def self.process_requested
    inputs = Hash.new { |h, k| h[k] = Hash.new(BigDecimal(0)) }
    outputs = Hash.new { |h, k| h[k] = Hash.new(BigDecimal(0)) }
    pending_amounts = Hash.new(BigDecimal(0))
    pending_payouts = Hash.new(BigDecimal(0))
    payouts = Hash.new

    TokenWithdrawal.transaction do
      TokenWithdrawal.requested.order(id: :asc).each do |withdrawal|
        required_amount = withdrawal.amount

        inputs_diff = Hash.new(BigDecimal(0))
        pending_amounts_diff = Hash.new(BigDecimal(0))
        pending_payouts_diff = Hash.new(BigDecimal(0))
        votes_diff = []

        votes[[withdrawal.payee_id, withdrawal.token_type_id]].each do |vote|
          available_amount = lambda do
            vote.amount - pending_amounts[vote.id] - pending_amounts_diff[vote.id]
          end
          available_payout = lambda do
            vote.payout - pending_payouts[vote.payout_id] - pending_payouts_diff[vote.payout_id]
          end

          bounds = [required_amount, available_amount.call]
          bounds << available_payout.call if vote.is_completed
          input_amount = bounds.min

          inputs_diff[vote.address] += input_amount
          pending_amounts_diff[vote.id] += input_amount
          if vote.is_completed
            pending_payouts_diff[vote.payout_id] += input_amount 
            payouts[vote.payout_id] ||= vote.payout
          end
          required_amount -= input_amount

          if available_amount.call == 0 || (available_payout.call == 0 && vote.is_completed)
            votes_diff << vote
          end
          break if required_amount == 0
        end

        if required_amount > 0
          withdrawal.reject!
          next
        end
        inputs[withdrawal.token_type].merge!(inputs_diff) { |k, v1, v2| v1+v2 }
        pending_amounts.merge!(pending_amounts_diff) { |k, v1, v2| v1+v2 }
        pending_payouts.merge!(pending_payoutss_diff) { |k, v1, v2| v1+v2 }
        votes[[withdrawal.payee_id, withdrawal.token_type_id]] -= votes_diff
        outputs[withdrawal.token_type][withdrawal.address] += withdrawal.amount
      end

      transactions = Hash.new
      outputs.keys.each do |token_t|
        common_addresses = inputs[token_t].keys.to_set & outputs[token_t].keys.to_set
        common_addresses.each do |address|
          min_amount = min([inputs[token_t][address], outputs[token_t][address]])
          inputs[token_t][address] -= min_amount
          inputs[token_t].delete(address) if inputs[token_t][address] == 0
          outputs[token_t][address] -= min_amount
          outputs[token_t].delete(address) if outputs[token_t][address] == 0
        end

        # TODO: obsluga bledow RPC
        rpc = RPC.get_rpc(token_t)
        txid, tx = rpc.create_raw_tx(inputs[token_t], outputs[token_t])
        transactions[token_t] = {txid: txid, tx: tx}
      end
      TokenTransaction.create(transactions.values)
      
      pp_updates, pp_deletions = pending_payouts.parition do |payout_id, pending_amount|
        payouts[payout_id] > pending_amount
      end
      payout_updates += pp_updates.map do |payout_id, pending_amount|
        [payout_id, {amount: payouts[payout_id]-pending_amount}]
      end
      payout_updates.transpose
      TokenPayout.update(payout_updates[0], payout_updates[1])
      payout_deletions += pp_deletions.map { |payout_id, *| payout_id }
      TokenPayout.destroy(payout_deletions)

      pending_outflows = pending_amounts.map do |vote_id, pending_amount|
        {
          token_vote_id: vote_id,
          # FIXME
          token_transaction: transactions[],
          amount: pending_amount
        }
      end
      TokenPendingOutflows.create(pending_outflows)

      # TODO: update TokenWithdrawal o tokentransaction
    end
  end

  protected

  def list_expired_votes
    TokenVote.expired
      .joins('LEFT OUTER JOIN token_pending_outflows ON 
              token_votes.id = token_pending_outflows.token_vote_id')
      .group('token_votes.id')
      .select('token_votes.id as id',
              'token_votes.voter_id as user_id',
              'token_votes.token_type_id as token_type_id',
              'token_votes.amount_conf-SUM(token_pending_outflows.amount) as amount',
              'token_votes.address as address',
              'token_votes.is_completed ad is_completed')
      .having('amount > 0')
      .group_by { |vote| [vote.user_id, vote.token_type_id] }
  end

  def list_completed_votes
    TokenVote.completed.joins(:token_payout)
      .joins('LEFT OUTER JOIN token_pending_outflows ON 
              token_votes.id = token_pending_outflows.token_vote_id')
      .group('token_votes.id')
      .select('token_votes.id as id',
              'token_payouts.payee_id as user_id',
              'token_votes.token_type_id as token_type_id',
              'token_votes.amount_conf-SUM(token_pending_outflows.amount) as amount',
              'token_votes.address as address',
              'token_votes.is_completed ad is_completed',
              'token_payouts.id as payout_id',
              'token_payouts.amount as payout')
      .having('amount > 0')
      .group_by { |vote| [vote.user_id, vote.token_type_id] }
  end

  def set_defaults
    if new_record?
      self.is_rejected ||= false
    end
  end
end

