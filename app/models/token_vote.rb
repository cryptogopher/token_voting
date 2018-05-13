class TokenVote < ActiveRecord::Base

  class Error < RuntimeError
    def to_s
      "TokenVote method error: #{super}"
    end
  end

  belongs_to :issue
  belongs_to :voter, class_name: 'User'

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

  enum token: {BTC: 0, BCH: 1, BTCTEST: 1000, BTCREG: 2000}
  #enum status: [:requested, :unconfirmed, :confirmed, :resolved, :expired, :refunded]

  validates :voter, :issue, presence: true, associated: true
  validates :duration, inclusion: { in: DURATIONS.values }
  validates :expiration, :address, presence: true
  validates :token, inclusion: { in: tokens.keys }
  validates :amount_conf, numericality: { grater_than_or_equal_to: 0 }
  validates :amount_unconf, numericality: true

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
    self.is_completed
  end

  def expired?
    self.expiration <= Time.current && !self.completed?
  end

  scope :active, -> { where(is_completed: false).where("expiration > ?", Time.current) }
  scope :completed, -> { where(is_completed: true) }
  scope :expired, -> { where(is_completed: false).where("expiration <= ?", Time.current) }

  # Updates 'is_completed' after issue edit and computes payouts on completion
  def self.issue_edit_hook(issue, journal)
    detail = journal.details.where(prop_key: 'status_id').pluck(:old_value, :value)
    prev_issue_status, curr_issue_status = detail.first if detail
    issue_prev_completed = is_issue_completed?(prev_issue_status)
    issue_curr_completed = is_issue_completed?(curr_issue_status)

    # Only update token_vote if:
    # - issue's checkpoint _changed_ from/to final checkpoint
    return if issue_prev_completed == issue_curr_completed
    # - token_vote did not expire
    # - token_vote expired but status changes from completed to not-completed
    issue.token_votes.each do |tv|
      if tv.expiration > Time.current
        tv.is_completed = issue_curr_completed
      elsif issue_curr_completed == false
        tv.is_completed = false
      end
      tv.save
    end

    if issue_curr_completed == true
      # Ordering by journals.created_on is unreliable, as it has 1sec precision
      status_history = issue.journal_details
        .where(prop_key: 'status_id')
        .order('journals.id ASC')
        .pluck('journals.user_id', 'journal_details.value')

      shares = Setting.plugin_token_voting['checkpoints']['shares'].map {|s| s.to_f}
      statuses = Setting.plugin_token_voting['checkpoints']['statuses']

      checkpoints = Hash.new(0)
      statuses.each_with_index.map do |checkp_statuses, checkp_index|
        checkp_statuses.map { |status| checkpoints[status] = checkp_index + 1 }
      end

      payees = Array.new(shares.count) 
      # Checkpoint numbers are 1 based
      prev_checkpoint = 0
      status_history.each do |user_id, status|
        curr_checkpoint = checkpoints[status]
        if curr_checkpoint > prev_checkpoint
          payees.fill(user_id, prev_checkpoint...curr_checkpoint)
        end
        prev_checkpoint = curr_checkpoint
      end

      payouts = Hash.new(0)
      payees.each_with_index do |payee, checkpoint| 
        payouts[payee] += shares[checkpoint] if shares[checkpoint] > 0
      end

      total_amount_per_token = issue.token_votes.completed.group(:token).sum(:amount_conf)

      payouts.each do |user_id, share|
        total_amount_per_token.each do |token, amount|
          # FIXME: potential rounding errors - sum of amounts should equal sum of payouts
          tp = TokenPayout.new(issue: issue, payee: User.find(user_id), token: token,
                               amount: share*amount)
          tp.save
        end
      end
    else
      issue.token_payouts.delete_all
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
    minimum_conf = Setting.plugin_token_voting[self.token]['min_conf'].to_i
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
      self.token ||= Setting.plugin_token_voting['default_token']
      self.amount_conf ||= 0
      self.amount_unconf ||= 0
      self.is_completed ||= false
    end
  end

  def self.is_issue_completed?(status)
    Setting.plugin_token_voting['checkpoints']['statuses'].last.include?(status)
  end
end

