class TokenVote < ActiveRecord::Base
  unloadable

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

  validates :user, :issue, presence: true, associated: true
  validates :duration, inclusion: { in: DURATIONS.values }
  validates :expiration, :address, presence: true
  validates :token, inclusion: { in: tokens.keys }
  validates :amount_conf, :amount_unconf, numericality: { grater_than_or_equal_to: 0 }

  after_initialize :set_defaults

  #enum status: [:requested, :unconfirmed, :confirmed, :resolved, :expired, :refunded]

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
    raise RuntimeError, 'Re-generating TokenVote address' if self.address

    rpc = RPC.get_rpc(self.token)
    # Is there more efficient way to generate unique addressess using RPC?
    # (under all circumstances, including removing wallet file from RPC daemon)
    begin
      addr = rpc.getnewaddress
    end while TokenVote.exists?({token: self.token, address: addr})

    self.address = addr
  end

  def update_received_amount
    rpc = RPC.get_rpc(self.token)
    minimum_conf = Settings.plugin_token_voting[self.token.to_sym][:min_conf]
    self.amount_unconf = rpc.getreceivedbyaddress(address: self.address, minconf: 0)
    self.amount_conf = rpc.getreceivedbyaddress(address: self.address, minconf: minimum_conf)
  end

  # Executed when wallet tx changes (bitcoind --walletnotify cmdline option)
  def self.wallet_notify(txid)
    rpc = RPC.get_rpc(self.token)
    tx = rpc.gettransaction(txid)

    tx['details'].each do |detail|
      token_vote = TokenVote.find_by(address: detail['address'])
      raise RuntimeError, 'Multiple TokenVotes with same address' if token_vote.many?
      if token_vote.any?
        token_vote.first.update_received_amount
      end
    end
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

