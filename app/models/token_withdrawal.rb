# Withdrawal assumptions:
# - user withdraws amount without specifying exact TokenVotes from which amount
# will be withdrawn. It is up to plugin to decide on optimal funds souce. User can
# withdraw sum of all available amounts in one go.
# - user can withdraw part of the funds, including multiple withdraws of the
# exact same amount to same output address(es).
# - user can cancel withdrawal before it has been fulfilled (i.e. before status
# changes to 'pending').
# - plugin has to effectively batch withdrawals to incur minimal fees, including
# merger of multiple withdrawals for the same user/token in one tx.
# - loss of information regarding withdrawals (e.g. token_withdrawals table corruption or
# deletion) may not incur double withdrawals.
#
# Withdrawal statuses:
# - requested - requested by user, tx not prepared, user can still cancel.
# Withdrawal contains only token_type, amount and destination address, without
# specification of source TokenVotes. Requested withdrawal is not reflected in
# TokenVotes#pending_withdrawals nor TokenPayouts.
# - pending - tx prepared and waiting to be sent or has already been sent, tx
# has less than min_conf confirmations, user cannot cancel withdrawal.
# Withdrawal is reflected in TokenVotes#pending_withdrawals and TokenPayouts.
# - processed - tx has been sent and has at least min_conf confirmations.
# TokenVotes#pending_withdrawals for processed withdrawal is canceled as it is
# already reflected in TokenVotes#amount_conf.

class TokenWithdrawal < ActiveRecord::Base
  belongs_to :payee, class_name: 'User'
  belongs_to :token_type

  validates :payee, :token_type, presence: true, associated: true
  validates :amount, numericality: { grater_than_or_equal_to: 0 }
  validates :address, uniqueness: true

  scope :requested, -> { where(txid: nil) }
  scope :pending, -> { where.not(txid: nil).where(is_processed: false) }
  scope :processed, -> { where.not(txid: nil).where(is_processed: true) }
end

