class TokenVote < ActiveRecord::Base

  class Error < RuntimeError
    def to_s
      "TokenVote method error: #{super}"
    end
  end

  belongs_to :issue
  belongs_to :voter, class_name: 'User'
  belongs_to :resolver, class_name: 'User'
  belongs_to :integrator, class_name: 'User'

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

  enum token: {BTC: 0, BCH: 1, BTCTEST: 1000}
  #enum status: [:requested, :unconfirmed, :confirmed, :resolved, :expired, :refunded]

  validates :voter, :issue, presence: true, associated: true
  validates :resolver, :integrator, associated: true
  validates :duration, inclusion: { in: DURATIONS.values }
  validates :expiration, :address, presence: true
  validates :token, inclusion: { in: tokens.keys }
  validates :amount_conf, :amount_unconf, numericality: { grater_than_or_equal_to: 0 }

  after_initialize :set_defaults

  def duration=(value)
    super(value.to_i)
    self[:expiration] = Time.current + self[:duration]
  end

  def funded?
    self.amount_unconf > 0 || self.amount_conf > 0
  end

  def visible?(user = User.current)
    self.issue.visible? &&
      self.voter == user &&
      user.allowed_to?(:manage_token_votes, self.issue.project)
  end

  def deletable?
    self.visible? && !self.funded?
  end

  def completed?
    self.completed
  end

  def expired?
    self.expiration <= Time.current && !self.completed?
  end

  scope :completed, -> { where(completed: true) }
  scope :expired, -> { where(completed: false).where("expiration <= ?", Time.current) }
  scope :active, -> { where(completed: false).where("expiration > ?", Time.current) }

  # Updates 'completed' after issue edit
  def self.issue_edit_hook(issue, journal)
    detail = journal.details.where(prop_key: 'status_id').pluck(:old_value, :value)
    old_status, new_status = detail.first if detail
    was_completed = is_status_completed(old_status)
    is_completed = is_status_completed(new_status)

    # Only update token_vote if:
    # - issue's checkpoint changed from/to final checkpoint
    return if was_completed == is_completed
    # - token_vote did not expire
    # - token_vote expired but status changes from completed to not-completed
    issue.token_votes.each do |tv|
      if tv.expiration > Time.current
        self.completed = is_completed
      elsif is_completed == false
        self.completed = false
      end
    end
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

  def update_amounts
    rpc = RPC.get_rpc(self.token)
    minimum_conf = Setting.plugin_token_voting[self.token.to_sym][:min_conf].to_i
    self.amount_conf = 
      rpc.get_received_by_address(self.address, minimum_conf)
    self.amount_unconf = 
      rpc.get_received_by_address(self.address, 0) - self.amount_conf
  end

  def self.compute_stats(token_votes)
    total_stats = Hash.new {|hash, key| hash[key] = Hash.new}
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

  def self.update_txn_amounts(token, txid)
    token = token.to_sym
    raise Error, "Invalid token: #{token.to_s}" unless tokens.has_key?(token)

    rpc = RPC.get_rpc(token)
    addresses = rpc.get_tx_addresses(txid)
    TokenVote.where(token: tokens[token], address: addresses).each do |tv|
      tv.update_amounts
      tv.save
    end
  end

  def self.update_unconfirmed_amounts(token, blockhash)
    token = token.to_sym
    raise Error, "Invalid token: #{token.to_s}" unless tokens.has_key?(token)

    rpc = RPC.get_rpc(token)
    TokenVote.where('token = ? and amount_unconf != 0', tokens[token]).each do |tv|
      tv.update_amounts
      tv.save
    end
  end

  protected

  def set_defaults
    if new_record?
      self.duration ||= 1.month
      self.token ||= Setting.plugin_token_voting[:default_token]
      self.amount_conf ||= 0
      self.amount_unconf ||= 0
      self.completed ||= false
    end
  end

  def is_status_completed?(status)
    Setting.plugin_token_voting[:checkpoints][:statuses].last.include?(status)
  end
end

