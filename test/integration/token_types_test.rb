require File.expand_path('../../test_helper', __FILE__)

class IssuesTest < Redmine::IntegrationTest
  fixtures :token_types, :issues, :issue_statuses, :issue_priorities,
    :users, :email_addresses, :trackers, :projects, :journals, :journal_details

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

  def test_new_token_type
    get new_token_type_path
    assert_response :ok
  end

  def test_create_token_type
    assert_difference 'TokenType.count', 1 do
      post token_types_path, {
        token_type: {
          name: "BTC",
          rpc_uri: "http://regtest-wallet:7nluWvQfpWTewrCXpChUkoRShigXs29H@172.17.0.1:10782",
          min_conf: 8,
          is_default: true
        }
      }
      assert_nil flash[:error]
      assert_redirected_to plugin_settings_path('token_voting')
    end
  end

  def test_edit_token_type
    get edit_token_type_path(token_types(:BTCREG))
    assert_response :ok
  end

  def test_update_token_type
    assert_equal 6, TokenType.find_by(name: :BTCREG).min_conf
    patch token_type_path(token_types(:BTCREG)), {
      token_type: {
        min_conf: 10
      }
    }
    assert_nil flash[:error]
    assert_redirected_to plugin_settings_path('token_voting')
    assert_equal 10, TokenType.find_by(name: :BTCREG).min_conf
  end

  def test_destroy_token_type
    assert token_types(:BTCREG).deletable?
    assert_difference 'TokenType.count', -1 do
      delete token_type_path(token_types(:BTCREG))
      assert_nil flash[:error]
      assert_redirected_to plugin_settings_path('token_voting')
    end
    assert_nil TokenType.find_by(name: :BTCREG)
  end

  def test_destroy_token_type_referenced_by_token_vote_should_fail
    # TODO
  end
end

