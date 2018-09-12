require File.expand_path('../../test_helper', __FILE__)

class SettingsTest < Redmine::IntegrationTest
  fixtures :token_types, :issues, :issue_statuses, :users, :email_addresses,
    :trackers, :projects, :journals, :journal_details

  def setup
    super
    setup_plugin

    log_user 'alice', 'foo'
    User.current.admin = true
    User.current.save!
  end

  def teardown
    super
    logout_user
  end

  def test_get_plugin_settings
    get plugin_settings_path('token_voting')
    assert_response :ok
  end

  def test_post_plugin_settings
    post plugin_settings_path('token_voting'), {
      settings: {
        checkpoints: {
          statuses: [issue_statuses(:pulled).id, '', issue_statuses(:closed).id, ''],
          shares: [0.98, 0.02]
        }
      }
    }
    assert_redirected_to plugin_settings_path('token_voting')
    assert_equal ["#{issue_statuses(:pulled).id}"],
      Setting.plugin_token_voting['checkpoints']['statuses'].first
    assert_equal ["#{issue_statuses(:closed).id}"],
      Setting.plugin_token_voting['checkpoints']['statuses'].last
    assert_equal "0.98", Setting.plugin_token_voting['checkpoints']['shares'].first
    assert_equal "0.02", Setting.plugin_token_voting['checkpoints']['shares'].last
    assert_equal 2, Setting.plugin_token_voting['checkpoints']['statuses'].length
    assert_equal 2, Setting.plugin_token_voting['checkpoints']['statuses'].length
  end
end
