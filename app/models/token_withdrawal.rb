# Withdrawal assumptions:
# - user withdraws amount without specifying exact TokenVotes from which amount
# will be withdrawn. It is up to plugin to decide on optimal funds source. User can
# withdraw sum of all available amounts in one go.
# - user can withdraw part of the funds, including multiple withdraws of the
# exact same amount to same output address(es).
# - user can cancel withdrawal before it has been fulfilled (i.e. before status
# changes to 'pending').
# - plugin has to effectively batch withdrawals to incur minimal fees, including
# merger of multiple withdrawals for the same token (incl. different users) in one tx.
# - loss of information regarding withdrawals (e.g. token_withdrawals table corruption or
# deletion) must not incur double withdrawals.
# - fees are deduced from withdrawal amount to enable withdrawal of all available
# amount. Plugin is not meant to be used as wallet, so control of exact output
# amount is not required.
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
# - rejected - at the time of processing requested withdrawal, not enough funds
# is available (e.g. because completed issue has been reverted to uncompleted).

class TokenWithdrawal < ActiveRecord::Base
  belongs_to :payee, class_name: 'User'
  belongs_to :token_type
  belongs_to :token_transaction

  validates :payee, :token_type, presence: true, associated: true
  validates :token_transaction, associated: true
  validates :amount, numericality: { greater_than: 0 }
  validates :amount, numericality: { 
    less_than_or_equal_to: :amount_withdrawable,
    if: :requested?,
  }
  validates :address, presence: true
  validates_each :address do |record, attr, value|
    begin
      unless RPC::get_rpc(record.token_type).is_address_valid?(value)
        record.errors.add(:address, "is invalid or has unsupported format")
      end
    rescue Error => e
      record.errors.add(:address, "cannot be validated due to error (#{e.message})")
    end
  end
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
    !self.rejected? && self.token_transaction.blank?
  end

  def pending?
    self.token_transaction.present? && !self.token_transaction.is_processed
  end

  def processed?
    self.token_transaction.present? && self.token_transaction.is_processed
  end

  def rejected?
    self.is_rejected
  end

  def deletable?
    self.requested? && (self.payee == User.current)
  end

  def status
    if self.requested?
      :requested
    elsif self.pending?
      :pending
    elsif self.processed?
      :processed
    else
      :rejected
    end
  end

  def amount_withdrawable
    total = 0.to_d
    TokenWithdrawal.transaction do
      # TODO: optimize first 3 queries into 1 with joins
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
    inputs = Hash.new { |h1, k1| h1[k1] = Hash.new { |h2, k2| h2[k2] = Hash.new(0.to_d) } }
    outputs = Hash.new { |h, k| h[k] = Hash.new(0.to_d) }
    pending_outflows = Hash.new(0.to_d)
    pending_payouts = Hash.new(0.to_d)
    payout_amounts = Hash.new
    vote_token_types = Hash.new

    TokenWithdrawal.transaction do
      votes =  TokenVote.inactive
        .joins('LEFT OUTER JOIN token_payouts ON
                token_votes.issue_id = token_payouts.issue_id')
        .joins('LEFT OUTER JOIN token_pending_outflows ON 
                token_votes.id = token_pending_outflows.token_vote_id')
        .group('token_votes.id', 'token_payouts.id')
        .select(
          'token_votes.id as id',
          'COALESCE(token_payouts.payee_id, token_votes.voter_id) as user_id',
          'token_votes.token_type_id as token_type_id',
          'token_votes.amount_conf-COALESCE(SUM(token_pending_outflows.amount), 0) as amount',
          'token_votes.address as address',
          'token_votes.is_completed as is_completed',
          'token_payouts.id as payout_id',
          'token_payouts.amount as payout')
        .having('amount > 0')
        .group_by { |vote| [vote.user_id, vote.token_type_id] }
      votes.default = []

      requested_withdrawals = TokenWithdrawal.requested.order(id: :asc)
      requested_withdrawals.each do |withdrawal|
        required_amount = withdrawal.amount

        inputs_diff = Hash.new(0.to_d)
        pending_outflows_diff = Hash.new(0.to_d)
        pending_payouts_diff = Hash.new(0.to_d)
        votes_diff = []

        votes[[withdrawal.payee_id, withdrawal.token_type_id]].each do |vote|
          bounds = [required_amount]
          bounds << vote.amount - pending_outflows[vote.id] - pending_outflows_diff[vote.id]
          if vote.is_completed
            bounds << vote.payout - pending_payouts[vote.payout_id] -
              pending_payouts_diff[vote.payout_id]
          end
          input_amount = bounds.min
          if bounds.drop(1).min == input_amount
            votes_diff << vote
          end

          inputs_diff[vote.address] += input_amount
          pending_outflows_diff[vote.id] += input_amount
          vote_token_types[vote.id] = withdrawal.token_type
          if vote.is_completed
            pending_payouts_diff[vote.payout_id] += input_amount 
            payout_amounts[vote.payout_id] = vote.payout
          end
          required_amount -= input_amount

          break if required_amount == 0
        end

        if required_amount > 0
          withdrawal.reject!
          next
        end
        inputs_hash = inputs[withdrawal.token_type][withdrawal.address]
        inputs_hash.merge!(inputs_diff) { |k, v1, v2| v1+v2 }
        outputs[withdrawal.token_type][withdrawal.address] += withdrawal.amount
        pending_outflows.merge!(pending_outflows_diff) { |k, v1, v2| v1+v2 }
        pending_payouts.merge!(pending_payouts_diff) { |k, v1, v2| v1+v2 }
        votes[[withdrawal.payee_id, withdrawal.token_type_id]] -= votes_diff
      end

      tx_params = Hash.new
      outputs.keys.each do |token_t|
        rpc = RPC.get_rpc(token_t)
        ntxid, tx = rpc.create_raw_tx(inputs[token_t], outputs[token_t])
        tx_params[token_t] = {ntxid: ntxid, tx: tx}
      end

      transactions = tx_params.keys.zip(TokenTransaction.create(tx_params.values)).to_h
      
      tp_updates, tp_deletes = pending_payouts.partition do |payout_id, pending_outflow|
        payout_amounts[payout_id] > pending_outflow
      end
      tp_updates.map! do |payout_id, pending_outflow|
        [payout_id, {amount: payout_amounts[payout_id]-pending_outflow}]
      end
      TokenPayout.update(*tp_updates.transpose) unless tp_updates.empty?
      tp_deletes.map! { |payout_id, *| payout_id }
      TokenPayout.destroy(tp_deletes) unless tp_deletes.empty?

      po_params = pending_outflows.map do |vote_id, pending_outflow|
        {token_vote_id: vote_id,
         token_transaction: transactions[vote_token_types[vote_id]],
         amount: pending_outflow}
      end
      TokenPendingOutflow.create(po_params) unless po_params.empty?

      rw_params = requested_withdrawals.map do |withdrawal|
        [withdrawal.id, {token_transaction: transactions[withdrawal.token_type]}]
      end
      TokenWithdrawal.update(*rw_params.transpose) unless rw_params.empty?
    end
  end

  protected

  def set_defaults
    if new_record?
      self.token_type ||= TokenType.find_by_is_default(true) || TokenType.all.first
      self.is_rejected ||= false
    end
  end
end

