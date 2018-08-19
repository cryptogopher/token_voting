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
      post "#{withdraw_token_vote_path}.js", params: {token_withdrawal: {
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

  def test_withdraw_from_expired_funded_vote
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    fund_token_vote(vote1, 0.5, @min_conf)
    travel(1.day+1.minute)

    vote1.reload
    assert vote1.expired?
    assert vote1.funded?
    withdraw_token_vote(amount: 0.5)
  end

  def test_withdraw_from_expired_funded_vote_of_excess_amount_should_fail
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    fund_token_vote(vote1, 0.5, @min_conf)
    travel(1.day+1.minute)

    vote1.reload
    assert vote1.expired?
    assert vote1.funded?
    withdraw_token_vote_should_fail(amount: 0.50000001)
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

  def test_withdraw_from_completed_funded_vote
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    fund_token_vote(vote1, 0.37, @min_conf)
    update_issue_status(@issue1, issue_statuses(:closed))

    vote1.reload
    assert vote1.completed?
    assert vote1.funded?
    withdraw_token_vote(amount: 0.37)
  end

  def test_withdraw_from_completed_funded_vote_of_excess_amount_should_fail
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    fund_token_vote(vote1, 0.37, @min_conf)
    update_issue_status(@issue1, issue_statuses(:closed))

    vote1.reload
    assert vote1.completed?
    assert vote1.funded?
    withdraw_token_vote_should_fail(amount: 0.37000001)
  end
end

