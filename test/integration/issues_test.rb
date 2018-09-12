require File.expand_path('../../test_helper', __FILE__)

class IssuesTest < Redmine::IntegrationTest
  fixtures :token_types, :issues, :issue_statuses, :issue_priorities,
    :users, :email_addresses, :trackers, :projects, :journals, :journal_details

  def setup
    super
    setup_plugin
  end

  def teardown
    super
    logout_user
  end

  def test_get_issue_with_vote
    log_user 'alice', 'foo'
    create_token_vote
    get issue_path(issues(:issue_01))
    assert_response :ok
  end
end
