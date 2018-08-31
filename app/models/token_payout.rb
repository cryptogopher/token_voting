class TokenPayout < ActiveRecord::Base
  belongs_to :issue
  belongs_to :payee, class_name: 'User'
  belongs_to :token_type
  has_many :token_votes, through: :issue

  validates :payee, :issue, :token_type, presence: true, associated: true
  validates :amount, numericality: { grater_than: 0 }

  scope :token, ->(token_t) { where(token_type: token_t) }
end

