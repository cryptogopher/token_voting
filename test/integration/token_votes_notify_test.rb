require File.expand_path('../../test_helper', __FILE__)

class TokenVotesNotifyTest < TokenVoting::NotificationIntegrationTest
  fixtures :issues, :issue_statuses, :users,
    :projects, :roles, :members, :member_roles, :enabled_modules

  def setup
    super
    setup_plugin
  end

  def teardown
    super
    logout_user
  end

  def test_create_only_if_authorized_and_has_permissions
    issue = issues(:issue_01)
    roles = users(:alice).members.find_by(project: issue.project_id).roles

    # cannot create without logging in
    assert_no_difference 'TokenVote.count' do
      post "#{issue_token_votes_path(issue)}.js", params: {
        token_vote: { token: 'BTCREG', duration: 1.day }
      }
    end
    assert_response :unauthorized

    # cannot create without permissions
    roles.each { |role| role.remove_permission! :manage_token_votes }
    log_user 'alice', 'foo'
    assert_no_difference 'TokenVote.count' do
      post "#{issue_token_votes_path(issue)}.js", params: {
        token_vote: { token: 'BTCREG', duration: 1.day }
      }
    end
    assert_response :forbidden
    roles.first.add_permission! :manage_token_votes

    # can create
    create_token_vote(issue)
  end

  def test_destroy_only_if_authorized_and_deletable
    issue = issues(:issue_01)

    # create vote for destruction
    log_user 'alice', 'foo'
    vote1 = create_token_vote(issue)
    vote2 = create_token_vote(issue)
    logout_user

    # cannot destroy without logging in
    assert_no_difference 'TokenVote.count' do
      delete "#{token_vote_path(vote1)}.js"
    end
    assert_response :unauthorized

    # cannot destroy if not owner
    log_user 'bob', 'foo'
    assert_no_difference 'TokenVote.count' do
      delete "#{token_vote_path(vote1)}.js"
    end
    assert_response :forbidden
    logout_user

    # cannot destroy without permissions
    log_user 'alice', 'foo'
    roles = users(:alice).members.find_by(project: issue.project_id).roles
    roles.each { |role| role.remove_permission! :manage_token_votes }
    assert_no_difference 'TokenVote.count' do
      delete "#{token_vote_path(vote1)}.js"
    end
    assert_response :forbidden
    roles.first.add_permission! :manage_token_votes

    # TODO: test for destruction without issue visibility

    # cannot destroy if founded
    assert_notifications 'walletnotify' => 1, 'blocknotify' => 0 do
      @network.send_to_address(vote2.address, 0.2)
    end
    vote2.reload
    assert_equal vote2.amount_unconf, 0.2
    assert_no_difference 'TokenVote.count' do
      delete "#{token_vote_path(vote2)}.js"
    end
    assert_response :forbidden

    min_conf = Setting.plugin_token_voting['BTCREG']['min_conf'].to_i

    assert_notifications 'walletnotify' => 1, 'blocknotify' => min_conf do
      @network.generate(min_conf)
    end
    vote2.reload
    assert_equal vote2.amount_conf, 0.2
    assert_no_difference 'TokenVote.count' do
      delete "#{token_vote_path(vote2)}.js"
    end
    assert_response :forbidden

    # can destroy
    destroy_token_vote(vote1)
  end

  def test_amount_update_on_walletnotify_and_blocknotify
    # For these tests to be executed successfully bitcoind regtest daemon must be
    # configured with 'walletnotify' and 'blocknotify' options properly.
    # 'walletnotify' occurs after:
    #  * first receiving a payment
    #  * first confirmation on the payment
    #  * you send a payment
    
    log_user 'alice', 'foo'

    vote = create_token_vote
    assert_notifications 'walletnotify' => 1, 'blocknotify' => 0 do
      @network.send_to_address(vote.address, 1.0)
    end
    vote.reload
    assert_equal vote.amount_unconf, 1.0
    assert_equal vote.amount_conf, 0

    min_conf = Setting.plugin_token_voting['BTCREG']['min_conf'].to_i
    assert_operator min_conf, :>, 2

    assert_notifications 'walletnotify' => 1, 'blocknotify' => 1 do
      @network.generate(1)
    end
    vote.reload
    assert_equal vote.amount_unconf, 1.0
    assert_equal vote.amount_conf, 0

    assert_notifications 'walletnotify' => 0, 'blocknotify' => (min_conf-2) do
      @network.generate(min_conf-2)
    end
    vote.reload
    assert_equal vote.amount_unconf, 1.0
    assert_equal vote.amount_conf, 0

    assert_notifications 'walletnotify' => 0, 'blocknotify' => 1 do
      @network.generate(1)
    end
    vote.reload
    assert_equal vote.amount_unconf, 0
    assert_equal vote.amount_conf, 1.0

    assert_notifications 'walletnotify' => 0, 'blocknotify' => 10 do
      @network.generate(10)
    end
    vote.reload
    assert_equal vote.amount_unconf, 0
    assert_equal vote.amount_conf, 1.0
  end
end

