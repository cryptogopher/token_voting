class TokenPayout < ActiveRecord::Base
  belongs_to :issue
  belongs_to :payee, class_name: 'User'

  enum token: TokenVote.tokens

  validates :payee, :issue, presence: true, associated: true
  validates :token, inclusion: { in: tokens.keys }
  validates :amount, numericality: true
end

