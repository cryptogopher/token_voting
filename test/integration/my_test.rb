require File.expand_path('../../test_helper', __FILE__)

class MyTest < TokenVoting::NotificationIntegrationTest
  fixtures :token_types, :issues, :issue_statuses, :users, :email_addresses,
    :trackers, :projects, :journals, :journal_details

  def setup
    super
    setup_plugin

    @issue1 = issues(:issue_01)
    @issue2 = issues(:issue_02)
    @min_conf = token_types(:BTCREG).min_conf
  end

  def teardown
    super
    logout_user
  end

  def test_token_votes_without_votes
    log_user 'alice', 'foo'
    get my_token_votes_path
    assert_response :ok
  end

  def test_token_votes_with_active_votes
    log_user 'alice', 'foo'
    vote1 = create_token_vote(duration: 1.week)
    vote2 = create_token_vote
    fund_token_vote(vote1, 0.17, 2)
    fund_token_vote(vote2, 2.03, @min_conf-1)

    [vote1, vote2].map(&:reload)
    assert vote1.active?
    assert vote2.active?

    get my_token_votes_path
    assert_response :ok
  end

  def test_token_votes_with_expired_funded_votes
    log_user 'alice', 'foo'
    vote1 = create_token_vote(duration: 1.week)
    vote2 = create_token_vote
    fund_token_vote(vote1, 0.17, 2)
    fund_token_vote(vote2, 2.03, @min_conf-1)
    travel(8.days)

    [vote1, vote2].map(&:reload)
    assert vote1.expired?
    assert vote2.expired?

    get my_token_votes_path
    assert_response :ok
  end

  def test_token_votes_with_completed_votes
    log_user 'alice', 'foo'
    vote1 = create_token_vote(duration: 1.week)
    vote2 = create_token_vote
    fund_token_vote(vote1, 0.17, 2)
    fund_token_vote(vote2, 2.03, @min_conf-1)
    update_issue_status(@issue1, issue_statuses(:closed))

    [vote1, vote2].map(&:reload)
    assert vote1.completed?
    assert vote2.completed?

    get my_token_votes_path
    assert_response :ok
  end

  def test_token_votes_with_withdrawal
    log_user 'alice', 'foo'
    vote1 = create_token_vote(duration: 1.week)
    vote2 = create_token_vote
    fund_token_vote(vote1, 0.17, 2)
    fund_token_vote(vote2, 2.03, @min_conf)
    travel(2.days)
    update_issue_status(@issue1, issue_statuses(:closed))
    withdrawal = withdraw_token_votes(address: @network.get_new_address, amount: 1.5)

    [vote1, vote2].map(&:reload)
    assert vote1.completed?
    assert vote2.expired?
    assert withdrawal.requested?

    get my_token_votes_path
    assert_response :ok
  end

  def test_token_votes_with_payout
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    fund_token_vote(vote1, 0.092, @min_conf)
    travel(1.day+1.hour)
    withdraw_token_votes(address: @network.get_new_address, amount: 0.033)
    payout_token_votes(tw_req: -1, tt: 1, tpo: 1)

    get my_token_votes_path
    assert_response :ok
  end
end
