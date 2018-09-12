require File.expand_path('../../test_helper', __FILE__)

class SettingsTest < Redmine::IntegrationTest
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

  def test_get_plugin_settings
    log_user 'alice', 'foo'
    User.current.admin = true
    User.current.save!

    get plugin_settings_path('token_voting')
    assert_response :ok
  end

  def test_post_plugin_settings
    # TODO
  end
end
