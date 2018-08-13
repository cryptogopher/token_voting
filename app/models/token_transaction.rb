class TokenTransaction < ActiveRecord::Base
  has_many :token_withdrawals
  has_many :token_pending_outflows

  validates :txid, :tx, presence: true
  validates :is_processed, inclusion: [false, true]

  after_initialize :set_defaults
  
  protected

  def set_defaults
    if new_record?
      self.is_processed ||= false
    end
  end
end

