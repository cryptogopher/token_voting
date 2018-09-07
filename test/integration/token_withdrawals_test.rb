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
    assert User.current.instance_of? AnonymousUser
    assert_no_difference 'TokenWithdrawal.count' do
      post "#{withdraw_token_votes_path}.js", params: {token_withdrawal: {
        token_type_id: token_types(:BTCREG),
        amount: 0.00000001,
        address: @network.get_new_address 
      }}
    end
    assert_response :unauthorized
  end

  def test_withdraw_without_votes_should_fail
    log_user 'alice', 'foo'
    assert @issue1.token_votes.empty?
    withdraw_token_votes_should_fail(amount: 0.00000001)
  end

  def test_withdraw_from_not_expired_not_completed_not_funded_vote_should_fail
    log_user 'alice', 'foo'
    vote1 = create_token_vote

    refute vote1.expired?
    refute vote1.completed?
    refute vote1.funded?
    withdraw_token_votes_should_fail(amount: 0.00000001)
  end

  def test_withdraw_from_not_expired_not_completed_funded_vote_should_fail
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    fund_token_vote(vote1, 0.5, @min_conf)

    vote1.reload
    refute vote1.expired?
    refute vote1.completed?
    assert vote1.funded?
    withdraw_token_votes_should_fail(amount: 0.00000001)
  end

  def test_withdraw_from_expired_not_funded_vote_should_fail
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    travel(1.day+1.minute)

    vote1.reload
    assert vote1.expired?
    refute vote1.funded?
    withdraw_token_votes_should_fail(amount: 0.00000001)
  end

  def test_withdraw_from_expired_funded_vote_only_up_to_amount
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    fund_token_vote(vote1, 0.5, @min_conf)
    travel(1.day+1.minute)

    vote1.reload
    assert vote1.expired?
    assert vote1.funded?
    withdraw_token_votes_should_fail(amount: 0.50000001)
    withdraw_token_votes(amount: 0.5)
  end

  def test_withdraw_from_completed_not_funded_vote_should_fail
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    update_issue_status(@issue1, issue_statuses(:closed))

    vote1.reload
    assert vote1.completed?
    refute vote1.funded?
    withdraw_token_votes_should_fail(amount: 0.00000001)
  end

  def test_withdraw_from_completed_funded_vote_only_up_to_share_amount
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    fund_token_vote(vote1, 0.37, @min_conf)
    update_issue_status(@issue1, issue_statuses(:resolved))
    logout_user

    log_user 'bob', 'foo'
    update_issue_status(@issue1, issue_statuses(:closed))

    vote1.reload
    assert vote1.completed?
    assert vote1.funded?
    withdraw_token_votes_should_fail(amount: 0.11100001)
    withdraw_token_votes(amount: 0.111)
  end

  def test_withdraw_multiple_withdrawals_from_mixed_votes_only_up_to_total_amount
    log_user 'alice', 'foo'
    vote1 = create_token_vote(duration: 1.week)
    fund_token_vote(vote1, 0.75, 1)
    update_issue_status(@issue1, issue_statuses(:pulled))
    logout_user

    log_user 'bob', 'foo'
    vote2 = create_token_vote
    fund_token_vote(vote2, 1.2, @min_conf)
    travel(2.days)
    update_issue_status(@issue1, issue_statuses(:closed))

    vote1.reload
    vote2.reload
    assert vote1.completed?
    assert vote1.funded?
    assert vote2.expired?
    assert vote2.funded?
    withdraw_token_votes(amount: 0.6)
    withdraw_token_votes(amount: 0.675)
    withdraw_token_votes_should_fail(amount: 0.00000001)
  end

  def test_payout_by_anonymous_should_fail
    assert User.current.instance_of? AnonymousUser
    assert_no_difference 'TokenTransaction.count' do
      post "#{payout_token_votes_path}.js"
    end
    assert_response :unauthorized
  end

  def test_payout_by_user_without_manage_token_votes_permission_should_fail
    roles = users(:alice).members.find_by(project: @issue1.project_id).roles
    roles.each { |role| role.remove_permission! :manage_token_votes }
    refute roles.any? { |role| role.has_permission? :manage_token_votes }

    log_user 'alice', 'foo'
    assert_no_difference 'TokenTransaction.count' do
      post "#{payout_token_votes_path}.js"
    end
    assert_response :forbidden
  end

  def test_payout_without_requested_withdrawals_should_not_change_state
    log_user 'alice', 'foo'
    assert_equal 0, TokenWithdrawal.requested.count
    assert_no_difference 'TokenTransaction.count' do
      assert_no_difference 'TokenWithdrawal.pending.count' do
        post "#{payout_token_votes_path}.js"
      end
    end
    assert_response :ok
  end

  def test_payout_one_requested_withdrawal_from_expired_vote
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    fund_token_vote(vote1, 0.68, @min_conf)
    travel(1.day+1.hour)
    withdraw_token_votes(amount: 0.33)

    assert_equal 1, TokenWithdrawal.requested.count
    payout_token_votes(tw_req: -1, tw_rej: 0, tt: 1, tpo: 1)
    sign_and_send_transactions(@min_conf, tw: 1, tt: 1, tpo: -1)
  end

  def test_payout_one_requested_withdrawal_from_completed_vote
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    fund_token_vote(vote1, 0.68, @min_conf)
    travel(1.day+1.hour)
    withdraw_token_votes(amount: 0.33)

    assert_equal 1, TokenWithdrawal.requested.count
    payout_token_votes(tw_requested: -1, tw_pending: 1, tw_processed: 0, tt: 1, tpo: 1)
    assert_difference 'TokenTransaction.pending.count', -1 do
      assert_difference 'TokenTransaction.processed.count', 1 do
        sign_and_send_transactions(@min_conf)
      end
    end
  end
end

