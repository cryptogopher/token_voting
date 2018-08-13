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

class TokenWithdrawal < ActiveRecord::Base
  belongs_to :payee, class_name: 'User'
  belongs_to :token_type
  belongs_to :token_transaction

  validates :payee, :token_type, presence: true, associated: true
  validates :token_transaction, associated: true
  validates :amount, numericality: { greater_than: 0 }
  validates :amount, numericality: { less_than_or_equal_to: :amount_withdrawable }
  validates :address, presence: true

  #after_initialize :set_defaults

  scope :requested, -> { where(token_transaction: nil) }
  scope :pending, -> { 
    joins(:token_transaction).where(token_transaction: {is_processed: false})
  }
  scope :processed, -> {
    joins(:token_transaction).where(token_transaction: {is_processed: true})
  }

  scope :token, ->(token_t) { where(token_type: token_t) }

  def amount_withdrawable
    amount_payouts = self.payee
      .token_payouts.token(self.token_type).sum(:amount)
    amount_expired = self.payee
      .token_votes.expired.token(self.token_type).sum(:amount_conf)
    amount_pending_expired = self.payee
      .token_votes.expired.token_pending_outflows.sum(:amount)
    requested_withdrawals = self.payee
      .token_withdrawals.token(self.token_type).where.not(id: self).sum(:amount)

    amount_payouts + amount_expired - amount_pending_expired - requested_withdrawals
  end

  protected

  #def set_defaults
  #  if new_record?
  #  end
  #end
end

