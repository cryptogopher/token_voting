require File.expand_path('../../test_helper', __FILE__)

class UiTest < Redmine::IntegrationTest
  fixtures :token_types, :issues, :issue_statuses, :users, :email_addresses,
    :trackers, :projects, :journals, :journal_details

  def setup
    super
    setup_plugin
  end

  def teardown
    super
    logout_user
  end

  def test_issue_view
  end

  def test_get_my_token_votes_without_votes
    log_user 'alice', 'foo'
    get my_token_votes_path
    assert_response :ok
  end

  def test_get_my_token_votes_with_votes
    log_user 'alice', 'foo'
    create_token_vote(amount: 12.7, duration: 1.week)
    create_token_vote(amount: 0.0064)
    get my_token_votes_path
    assert_response :ok
  end

  def test_get_plugin_settings
    log_user 'alice', 'foo'
    User.current.admin = true
    User.current.save!

    get plugin_settings_path('token_voting')
    assert_response :ok
  end
end
