require File.expand_path('../../test_helper', __FILE__)

class TokenWithdrawalNotifyTest < TokenVoting::NotificationIntegrationTest
  fixtures :token_types, :issues, :issue_statuses, :users,
    :projects, :roles, :members, :member_roles, :enabled_modules,
    :trackers, :workflow_transitions

  def setup
    super
    setup_plugin

    @issue1 = issues(:issue_01)
    @issue2 = issues(:issue_02)
    @min_conf = token_types(:BTCREG).min_conf

    Rails.logger.info "TEST #{name}"
  end

  def teardown
    super
    logout_user
  end

  def test_withdraw_by_anonymous_should_fail
    assert_no_difference 'TokenWithdrawal.count' do
      post "#{withdraw_token_vote_path}.js", params: {
        token: 'BTCREG', amount: 0.00000001, address: @network.get_new_address 
      }
    end
    assert_response :unauthorized
  end

  def test_withdraw_without_votes_should_fail
    log 'alice', 'foo'

    assert_no_difference 'TokenWithdrawal.count' do
      post "#{withdraw_token_vote_path}.js", params: {
        token: 'BTCREG', amount: 0.00000001, address: @network.get_new_address 
      }
      refute_nil flash[:error]
    end
    assert_response :forbidden
  end
end

