class TokenType < ActiveRecord::Base
  validates :name, :rpc_uri, presence: true
  validates :min_conf, numericality: { greater_than: 0 }
  validates :precision, numericality: { greater_than_or_equal_to: 0 }
  validates :is_default, inclusion: [true, false]
  validates :prev_sync_height, numericality: { greater_than_or_equal_to: 0 }

  after_initialize :set_defaults

  protected

  def set_defaults
    if new_record?
      self.rpc_uri ||= 'http://rpcuser:rpcpassword@hostname:8332'
      self.min_conf ||= 6
      self.precision ||= 8
      self.is_default ||= false
      self.prev_sync_height ||= 0
    end
  end
end

