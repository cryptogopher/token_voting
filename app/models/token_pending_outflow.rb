class TokenPendingOutflow < ActiveRecord::Base
  belongs_to :token_vote
  belongs_to :token_transaction

  validates :token_vote, :token_transaction, presence: true, associated: true
  validates :amount, numericality: { grater_than: 0 }
end

