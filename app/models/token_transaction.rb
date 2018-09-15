class TokenTransaction < ActiveRecord::Base
  has_many :token_withdrawals
  has_many :token_pending_outflows

  validates :ntxid, presence: true, uniqueness: true
  validates :tx, presence: true
  validates :is_processed, inclusion: [false, true]

  after_initialize :set_defaults
  
  scope :pending, -> { where(is_processed: false) }
  scope :processed, -> { where(is_processed: true) }

  def processed?
    self.is_processed
  end

  protected

  def set_defaults
    if new_record?
      self.is_processed ||= false
    end
  end
end

