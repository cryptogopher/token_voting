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
  }.freeze
  DEFAULT_DURATION = 1.month

  TOKENS = [
    "BTC",
    "BCH"
  ].freeze
  DEFAULT_TOKEN = "BTC"

  def initialize(args)
    super
    @issue, @user = args[:issue], args[:user]
    @expiration = Time.now + 3.months
  end
end
