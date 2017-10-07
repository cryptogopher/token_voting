class TokenVote < ActiveRecord::Base
  unloadable

  belongs_to :issue
  belongs_to :user

  EXPIRATION_PERIODS = {
    "1 week" => 1.week,
    "1 month" => 1.month,
    "3 months" => 3.months,
    "6 months" => 6.months,
    "1 year" => 1.year,
    "never" => 99.years
  }.freeze

  def initialize(args)
    super
    @issue, @user = args[:issue], args[:user]
    @expiration = Time.now + 3.months
  end

end
