require File.expand_path('../../test_helper', __FILE__)

class TokenVoteTest < ActiveSupport::TestCase
  fixtures :issues, :issue_statuses, :users, :token_votes, :token_payouts,
    :journals, :journal_details,
    :trackers, :projects

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end

