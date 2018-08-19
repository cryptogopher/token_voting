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
    withdraw_token_vote_should_fail(amount: 0.00000001)
  end

  def test_withdraw_from_not_expired_not_completed_not_funded_vote_should_fail
    log_user 'alice', 'foo'
    vote1 = create_token_vote

    refute vote1.expired?
    refute vote1.completed?
    refute vote1.funded?
    withdraw_token_vote_should_fail(amount: 0.00000001)
  end

  def test_withdraw_from_not_expired_not_completed_funded_vote_should_fail
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    fund_token_vote(vote1, 0.5, @min_conf)

    vote1.reload
    refute vote1.expired?
    refute vote1.completed?
    assert vote1.funded?
    withdraw_token_vote_should_fail(amount: 0.00000001)
  end

  def test_withdraw_from_expired_not_funded_vote_should_fail
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    travel(1.day+1.minute)

    vote1.reload
    assert vote1.expired?
    refute vote1.funded?
    withdraw_token_vote_should_fail(amount: 0.00000001)
  end

  def test_withdraw_from_expired_funded_vote_only_up_to_amount
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    fund_token_vote(vote1, 0.5, @min_conf)
    travel(1.day+1.minute)

    vote1.reload
    assert vote1.expired?
    assert vote1.funded?
    withdraw_token_vote_should_fail(amount: 0.50000001)
    withdraw_token_vote(amount: 0.5)
  end

  def test_withdraw_from_completed_not_funded_vote_should_fail
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    update_issue_status(@issue1, issue_statuses(:closed))

    vote1.reload
    assert vote1.completed?
    refute vote1.funded?
    withdraw_token_vote_should_fail(amount: 0.00000001)
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
    withdraw_token_vote_should_fail(amount: 0.11100001)
    withdraw_token_vote(amount: 0.111)
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
    withdraw_token_vote(amount: 0.6)
    withdraw_token_vote(amount: 0.675)
    withdraw_token_vote_should_fail(amount: 0.00000001)
  end
end

