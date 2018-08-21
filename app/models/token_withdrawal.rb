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
    TokenWithdrawal.transaction do
      requests_by_token = Hash.new { |hash, key| hash[key] = Hash.new }
      all_requests = TokenWithdrawal.requested.order(id: :desc)
        .group_by { |withdrawal| [withdrawal.payee, withdrawal.token_type] }
      all_requests.each do |(payee, token_t), requests|
        requests.each do |withdrawal|
          break if withdrawal.valid?
          withdrawal.reject!
        end
        requests.delete_if { |withdrawal| withdrawal.rejected? }
        requests_by_token[token_t][payee] = requests
      end

      expired_votes = nil
      completed_votes = nil
      payout_updates = []
      payout_deletions = []
      pending_outflows = []

      requests_by_token.each do |token_t, requests_by_payee|
        requests_by_payee do |payee, requests|
          required_amount = requests.sum(&:amount)

          expired_inputs = Hash.new
          expired_votes ||= list_expired_votes
          votes, expired_votes = expired_votes.partition do |*, voter_id, token_type_id|
            voter_id == payee.id && token_type_id == token_t.id
          end
          votes.each do |id, amount_conf, amount_pending, address, *|
            break if required_amount == 0
            input_amount = min([required_amount, amount_conf-amount_pending])
            expired_inputs[id] = [address, input_amount, amount_conf-amount_pending]
            required_amount -= input_amount
          end

          break if required_amount == 0

          completed_inputs = Hash.new
          completed_votes ||= list_completed_votes
          votes, completed_votes = completed_votes.partition do |*, payee_id, token_type_id|
            payee_id == payee.id && token_type_id == token_t.id
          end
          votes.group_by { |payout_id, payout_amount, *| [payout_id, payout_amount] }
          votes.each do |(payout_id, payout_amount), votes|
            break if required_amount == 0
            votes.each do |(*, vote_amount_conf, vote_address, payee_id, token_type_id)|
              break if required_amount == 0 || payout_amount == 0
              input_amount = min([payout_amount, vote_amount_conf, required_amount])
              completed_inputs[payout_id] = [vote_address, input_amount,
                                             vote_amount_conf, payout_amount]
              payout_amount -= input_amount
              required_amount -= input_amount
            end
          end
        end

        inputs = expired_inputs.values + completed_inputs.values
        inputs.map! { |(address, amount, *)| [address, amount] }
        requests_outputs = Hash.new(BigDecimal(0))
        outputs = requests.map { |tw| requests_outputs[tw.address] += tw.amount }.to_a

        rpc = RPC.get_rpc(token_t)
        txid, tx = rpc.create_raw_tx(inputs, outputs)
        tt = TokenTransaction.create(txid: txid, tx: tx)

        tp_updates, tp_deletions =
          completed_inputs.parition do |k, (*, input_amount, *, payout_amount)|
            payout_amount-input_amount > 0
          end
        payout_updates += tp_updates.map do |id, (*, input_amount, *, payout_amount)|
          [id, {amount: payout_amount-input_amount}]
        end
        payout_deletions += tp_deletions.map { |id, *| id }

        pending_outflows += expired_inputs.map do |id, (*, pending_amount, *)|
          {token_vote_id: id, token_transaction: tt, amount: pending_amount}
        end
      end

      payout_updates.transpose
      TokenPayout.update(payout_updates[0], payout_updates[1])
      TokenPayout.destroy(payout_deletions)
      TokenPendingOutflows.create(pending_outflows)
    end
  end

  protected

  def list_expired_votes
    TokenVote.expired.group(:id)
      .joins('LEFT OUTER JOIN token_pending_outflows ON 
              token_votes.id = token_pending_outflows.token_vote_id')
      .select('token_votes.id as id',
              'token_votes.amount_conf as amount_conf',
              'SUM(token_pending_outflows.amount) as amount_pending',
              'token_votes.address as address',
              'token_votes.voter_id as voter_id',
              'token_votes.token_type_id as token_type_id')
  end

  def list_completed_votes
    TokenPayout.joins(:token_vote).completed
      .select('token_payouts.id as payout_id',
              'token_payouts.amount as payout_amount',
              'token_votes.amount_conf as vote_amount_conf',
              'token_votes.address as vote_address',
              'token_payouts.payee_id as payee_id',
              'token_payouts.token_type_id as token_type_id')
  end

  def set_defaults
    if new_record?
      self.is_rejected ||= false
    end
  end
end

