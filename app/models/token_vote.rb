class TokenVote < ActiveRecord::Base
  unloadable

  belongs_to :issue
  belongs_to :user

  after_initialize :set_defaults

  DURATIONS = {
    "1 week" => 1.week,
    "1 month" => 1.month,
    "3 months" => 3.months,
    "6 months" => 6.months,
    "1 year" => 1.year,
  }.freeze
  STAT_PERIODS = {
    "1 hour" => 1.hour,
    "1 day" => 1.day,
    "3 days" => 3.days,
    "1 week" => 1.week,
    "2 weeks" => 2.weeks,
    "1 month" => 1.month,
    "3 months" => 3.months,
    "6 months" => 6.months,
  }.freeze


  enum token: [:BTC, :BCH]
  enum status: [:requested, :unconfirmed, :confirmed, :resolved, :expired, :refunded]

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
    self.visible? && self.requested?
  end

  protected

  def set_defaults
    if new_record?
      self.duration ||= 1.month
      self.token ||= :BCH
      self.amount ||= 0
      self.status ||= :requested
    end
  end

  private

  attr_writer :expiration
end

