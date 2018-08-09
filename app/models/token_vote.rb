class TokenVote < ActiveRecord::Base

  class Error < RuntimeError
    def to_s
      "TokenVote method error: #{super}"
    end
  end

  belongs_to :issue
  belongs_to :voter, class_name: 'User'
  belongs_to :token_type

  DURATIONS = {
    "1 day" => 1.day,
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

  #enum status: [:requested, :unconfirmed, :confirmed, :resolved, :expired, :refunded]

  validates :voter, :issue, :token_type, presence: true, associated: true
  validates :duration, inclusion: { in: DURATIONS.values }
  validates :expiration, :address, presence: true
  validates :address, uniqueness: true
  validates :amount_conf, :amount_in, numericality: { grater_than_or_equal_to: 0 }
  validates :amount_unconf, numericality: true

  after_initialize :set_defaults

  def duration=(value)
    super(value.to_i)
    self[:expiration] = Time.current + self[:duration]
  end

  def funded?
    self.amount_unconf > 0 || self.amount_in > 0
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
      tv.save!
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

      payouts = Hash.new(BigDecimal(0))
      payees.each_with_index do |payee, checkpoint| 
        payouts[payee] += shares[checkpoint] if shares[checkpoint] > 0
      end

      total_amount_per_token =
        issue.token_votes.completed.group(:token_type).sum(:amount_conf)

      payouts.each do |user_id, share|
        total_amount_per_token.each do |token_type, amount|
          # FIXME: potential rounding errors - sum of amounts should equal sum of payouts
          tp = TokenPayout.new(issue: issue, payee: User.find(user_id),
                               token_type: token_type, amount: share*amount)
          tp.save!
        end
      end
    else
      issue.token_payouts.delete_all
    end
  end

  def generate_address
    raise Error, 'Re-generating existing address' if self.address

    rpc = RPC.get_rpc(self.token_type)
    # Is there more efficient way to generate unique addressess using RPC?
    # (under all circumstances, including removing wallet file from RPC daemon)
    begin
      new_address = rpc.get_new_address
    end while TokenVote.exists?({token_type: self.token_type, address: new_address})

    self.address = new_address
  end

  def update_amounts
    rpc = RPC.get_rpc(self.token_type)
    # TODO: does it count coinbase txs?
    utxos = rpc.list_unspent(0, 9999999, [self.address])
    utxos_conf, utxos_unconf =
      utxos.partition { |utxo| utxo['confirmations'] >= self.token_type.min_conf }

    self.amount_conf = utxos_conf.sum { |utxo| utxo['amount'] }
    self.amount_unconf = utxos_unconf.sum { |utxo| utxo['amount'] }
  end

  def self.compute_stats(token_votes)
    total_stats = Hash.new {|hash, key| hash[key] = Hash.new}
    STAT_PERIODS.values.each do |period|
      # Get confirmed amount per token in given period
      stats = token_votes.
        where('expiration > ?', Time.current + period).
        group(:token_type).
        sum(:amount_conf)
      stats.each do |token_type, amount|
        total_stats[token_type.name][period] = amount if amount > 0.0
      end
    end
    return total_stats
  end

  def self.process_tx(token_type_name, txid)
    type = TokenType.find_by_name(token_type_name)
    raise Error, "Invalid token type name: #{token_type_name}" unless type

    rpc = RPC.get_rpc(type)
    inputs, outputs = rpc.get_tx_addresses(txid)
    TokenVote.where(address: inputs+outputs, token_type: type).each do |vote|
      vote.update_amounts
      vote.save!
    end
  end

  def self.process_block(token_type_name, blockhash)
    type = TokenType.find_by_name(token_type_name)
    raise Error, "Invalid token type name: #{token_type_name}" unless type

    rpc = RPC.get_rpc(type)

    # Update amount_in/_conf/_unconf for txs confirmed since last synced block.
    # - amount_in specifies total amount of incoming transactions to address.
    # It is necessary to compute how much can be withdrawn from 'expired' vote
    # (completed votes have this amount specified in TokenPayouts).
    # - amount_conf/_unconf must be updated for all confirmed txs, as 
    # 'walletnotify' may miss txs and they won't show as unconfirmed.
    # (so it is not enough to update amounts only for amount_unconf > 0 votes here).
    prev_blockhash = rpc.get_block_hash(type.prev_sync_height)
    incoming_txs = rpc.list_since_block(prev_blockhash, type.min_conf, true)
    next_block_height = rpc.get_block(incoming_txs['lastblock'])['height']
    return if type.prev_sync_height >= next_block_height

    #puts "GET processing from #{prev_blockhash}/#{type.prev_sync_height} to #{incoming_txs['lastblock']}/#{next_block_height}"

    TokenVote.transaction do
      incoming_txs['transactions'].each do |tx|
        inputs, outputs = rpc.get_tx_addresses(tx['txid'])
        TokenVote.where(address: inputs+outputs, token_type: type).each do |vote|
          if vote.address == tx['address'] && tx['category'] == 'receive' &&
              tx['confirmations'] >= type.min_conf
            vote.amount_in += tx['amount']
          end
          vote.update_amounts
          vote.save!
        end
      end
      type.prev_sync_height = next_block_height
      type.save!
    end
  end

  protected

  def set_defaults
    if new_record?
      self.duration ||= 1.month
      self.token_type ||= TokenType.find_by_default(true) || TokenType.all.first
      self.amount_conf ||= 0
      self.amount_in ||= 0
      self.amount_unconf ||= 0
      self.is_completed ||= false
    end
  end

  def self.is_issue_completed?(status)
    Setting.plugin_token_voting['checkpoints']['statuses'].last.include?(status)
  end
end

