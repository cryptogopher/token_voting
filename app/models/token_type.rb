class TokenType < ActiveRecord::Base
  has_many :token_votes
  has_many :token_payouts
  has_many :token_withdrawals

  validates :name, presence: true, uniqueness: true
  validates :rpc_uri, presence: true
  validates_each :rpc_uri do |record, attr, value|
    begin
      rpc = RPC::get_rpc(record)
      uri = rpc.uri.to_s
      rpc.uptime
    rescue RPC::ClassMissing => e
      record.errors.add(:name, "does not describe valid RPC class (#{e.message})")
    rescue RPC::Error, URI::Error => e
      record.errors.add(:rpc_uri,
                        "is invalid or does not point to reachable RPC daemon (#{e.message})")
    end
  end
  validates :min_conf, numericality: { greater_than: 0 }
  validates :is_default, inclusion: [true, false]
  validates :prev_sync_height, numericality: { greater_than_or_equal_to: 0 }

  after_initialize :set_defaults

  def deletable?
    self.token_votes.empty? && self.token_payouts.empty? && self.token_withdrawals.empty?
  end

  protected

  def set_defaults
    if new_record?
      self.rpc_uri ||= 'http://rpcuser:rpcpassword@hostname:8332'
      self.min_conf ||= 6
      self.is_default ||= TokenType.find_by(is_default: true).nil? ? true : false
      self.prev_sync_height ||= 0
    end
  end
end

