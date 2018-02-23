class TokenVote < ActiveRecord::Base
  unloadable

  class Error < Exception
    def to_s
      "TokenVote method error: #{super}"
    end
  end

  belongs_to :issue
  belongs_to :user

  DURATIONS = {
    "1 week" => 1.week,
    "1 month" => 1.month,
    "3 months" => 3.months,
    "6 months" => 6.months,
    "1 year" => 1.year,
  }
  STAT_PERIODS = {
    "1 hour" => 1.hour,
    "1 day" => 1.day,
    "3 days" => 3.days,
    "1 week" => 1.week,
    "2 weeks" => 2.weeks,
    "1 month" => 1.month,
    "3 months" => 3.months,
    "6 months" => 6.months,
  }

  enum token: {BTC: 0, BCH: 1}
  #enum status: [:requested, :unconfirmed, :confirmed, :resolved, :expired, :refunded]

  validates :user, :issue, presence: true, associated: true
  validates :duration, inclusion: { in: DURATIONS.values }
  validates :expiration, :address, presence: true
  validates :token, inclusion: { in: tokens.keys }
  validates :amount_conf, :amount_unconf, numericality: { grater_than_or_equal_to: 0 }

  after_initialize :set_defaults

  def duration=(value)
    super(value.to_i)
    self[:expiration] = Time.current + self[:duration]
  end

  def visible?
    self.issue.visible? &&
      self.user == User.current &&
      User.current.allowed_to?(:manage_token_votes, self.issue.project)
  end

  def deletable?
    self.visible? && !self.funded?
  end

  def funded?
    self.amount_unconf > 0 || self.amount_conf > 0
  end

  def generate_address
    raise Error, 'Re-generating existing address' if self.address

    rpc = RPC.get_rpc(self.token)
    # Is there more efficient way to generate unique addressess using RPC?
    # (under all circumstances, including removing wallet file from RPC daemon)
    begin
      new_address = rpc.get_new_address
    end while TokenVote.exists?({token: self.token, address: new_address})

    self.address = new_address
  end

  def update_received_amount
    rpc = RPC.get_rpc(self.token)
    minimum_conf = Settings.plugin_token_voting[self.token.to_sym][:min_conf]
    self.amount_unconf = 
      rpc.get_received_by_address(address: self.address, minconf: 0)
    self.amount_conf = 
      rpc.get_received_by_address(address: self.address, minconf: minimum_conf)
  end

  def self.compute_stats(token_votes)
    total_stats = Hash.new{|hash, key| hash[key] = Hash.new}
    STAT_PERIODS.values.each do |period|
      # Get confirmed amount per token in given period
      stats = token_votes.
        where('expiration > ?', Time.current + period).
        group(:token).
        sum(:amount_conf)
      stats.each do |token_index, amount|
        token_name = tokens.key(token_index)
        total_stats[token_name][period] = amount if amount > 0.0
      end
    end
    return total_stats
  end

  def self.update_amounts_by_txid(token, txid)
    token = token.to_sym
    raise Error, "Invalid token: #{token.to_s}" unless tokens.has_key?(token)

    rpc = RPC.get_rpc(token)
    addresses = rpc.get_tx_addresses(txid)
    TokenVote.where(address: addresses).each { |tv| tv.update_received_amount }
  end

  protected

  def set_defaults
    if new_record?
      self.duration ||= 1.month
      self.token ||= :BCH
      self.amount_conf ||= 0
      self.amount_unconf ||= 0
    end
  end
end

