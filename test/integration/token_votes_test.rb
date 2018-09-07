require File.expand_path('../../test_helper', __FILE__)

class TokenVotesNotifyTest < TokenVoting::NotificationIntegrationTest
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

  def test_create_vote_by_anonymous_should_fail
    assert User.current.instance_of? AnonymousUser
    assert_no_difference 'TokenVote.count' do
      post "#{issue_token_votes_path(@issue1)}.js", params: {
        token_vote: { token_type_id: token_types(:BTCREG).id, duration: 1.day }
      }
    end
    assert_response :unauthorized
  end

  def test_create_vote_without_permissions_should_fail
    roles = users(:alice).members.find_by(project: @issue1.project_id).roles
    roles.each { |role| role.remove_permission! :add_token_votes }
    refute roles.any? { |role| role.has_permission? :add_token_votes }

    log_user 'alice', 'foo'
    assert_no_difference 'TokenVote.count' do
      post "#{issue_token_votes_path(@issue1)}.js", params: {
        token_vote: { token_type_id: token_types(:BTCREG).id, duration: 1.day }
      }
    end
    assert_response :forbidden
  end

  def test_create_vote
    log_user 'alice', 'foo'
    create_token_vote
    # TODO: get issue page and check for valid content
  end

  def test_destroy_vote_by_anonymous_shoulf_fail
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    logout_user

    assert User.current.instance_of? AnonymousUser
    assert_no_difference 'TokenVote.count' do
      delete "#{token_vote_path(vote1)}.js"
    end
    assert_response :unauthorized
  end

  def test_destroy_vote_by_non_owner_should_fail
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    logout_user

    log_user 'bob', 'foo'
    assert_no_difference 'TokenVote.count' do
      delete "#{token_vote_path(vote1)}.js"
    end
    assert_response :forbidden
  end

  def test_destroy_vote_without_permissions_should_fail
    log_user 'alice', 'foo'
    vote1 = create_token_vote

    roles = users(:alice).members.find_by(project: @issue1.project_id).roles
    roles.each { |role| role.remove_permission! :add_token_votes }
    refute roles.any? { |role| role.has_permission? :add_token_votes }

    assert_no_difference 'TokenVote.count' do
      delete "#{token_vote_path(vote1)}.js"
    end
    assert_response :forbidden
  end

  # TODO: test for destruction without issue visibility

  def test_destroy_vote_funded_with_unconfirmed_tx_should_fail
    log_user 'alice', 'foo'
    vote1 = create_token_vote

    assert_notifications 'walletnotify' => 1, 'blocknotify' => 0 do
      txid = @network.send_to_address(vote1.address, 0.2)
    end
    vote1.reload
    assert_equal vote1.amount_unconf, 0.2
    assert_no_difference 'TokenVote.count' do
      delete "#{token_vote_path(vote1)}.js"
    end
    assert_response :forbidden

    assert_notifications 'walletnotify' => 1, 'blocknotify' => 1 do
      @network.generate(1)
    end
  end

  def test_destroy_vote_funded_with_confirmed_tx_should_fail
    log_user 'alice', 'foo'
    vote1 = create_token_vote

    min_conf = vote1.token_type.min_conf
    assert_notifications 'blocknotify' => min_conf do
      @network.send_to_address(vote1.address, 0.2)
      @network.generate(min_conf)
    end
    vote1.reload
    assert_equal vote1.amount_conf, 0.2
    assert_no_difference 'TokenVote.count' do
      delete "#{token_vote_path(vote1)}.js"
    end
    assert_response :forbidden
  end

  def test_destroy_vote
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    destroy_token_vote(vote1)
    # TODO: get issue page and check for valid content
  end

  # For these tests to be executed successfully bitcoind regtest daemon must be
  # configured with 'walletnotify' and 'blocknotify' options properly.
  # 'walletnotify' occurs after:
  #  * first receiving a payment (sometimes merged with first confirmation if
  #  block generated immediately after); use assert_in_mempool to wait for tx to
  #  arrive into @wallet mempool and generate this 'walletnotify'
  #  * first confirmation on the payment
  #  * you send a payment
  # At the end of test, block should be generated so there are no unconfirmed
  # txs which will potentially generate 'walletnotify' in subsequent functions.
  # Running assert_in_mempool at the end of assert_notifications is redundant
  # with waiting for 'walletnotify'.
  # Testing notifications:
  #   tail -f ../../log/test.log | egrep "(GET|POST|TEST)"
  def test_walletnotify_after_first_receiving_tx
    log_user 'alice', 'foo'
    vote1 = create_token_vote

    assert_notifications 'walletnotify' => 1, 'blocknotify' => 0 do
      txid = @network.send_to_address(vote1.address, 2.0)
    end
    vote1.reload
    assert_equal vote1.amount_unconf, 2.0
    assert_equal vote1.amount_conf, 0

    assert_notifications 'walletnotify' => 1, 'blocknotify' => 1 do
      @network.generate(1)
    end
  end

  def test_walletnotify_after_first_receiving_multiple_txs
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    vote2 = create_token_vote

    assert_notifications 'walletnotify' => 2, 'blocknotify' => 0 do
      txid1 = @network.send_to_address(vote1.address, 0.5)
      txid2 = @network.send_to_address(vote2.address, 2.33)
    end
    [vote1, vote2].map(&:reload)
    assert_equal vote1.amount_unconf, 0.5
    assert_equal vote1.amount_conf, 0
    assert_equal vote2.amount_unconf, 2.33
    assert_equal vote2.amount_conf, 0

    assert_notifications 'walletnotify' => 2, 'blocknotify' => 1 do
      @network.generate(1)
    end
  end

  def test_walletnotify_and_blocknotify_after_first_confirmation_of_tx
    log_user 'alice', 'foo'
    vote1 = create_token_vote

    assert_notifications 'walletnotify' => 2, 'blocknotify' => 1 do
      txid = @network.send_to_address(vote1.address, 0.6)
      assert_in_mempool @wallet, txid
      @network.generate(1)
    end
    vote1.reload
    assert_equal vote1.amount_unconf, 0.6
    assert_equal vote1.amount_conf, 0
  end

  def test_blocknotify_after_min_conf_minus_1_confirmations_of_tx
    log_user 'alice', 'foo'
    vote1 = create_token_vote

    assert_operator @min_conf, :>, 1
    assert_notifications 'blocknotify' => (@min_conf-1) do
      txid = @network.send_to_address(vote1.address, 0.8)
      @network.generate(@min_conf-1)
    end
    vote1.reload
    assert_equal vote1.amount_unconf, 0.8
    assert_equal vote1.amount_conf, 0
  end

  def test_blocknotify_after_min_conf_confirmations_of_tx
    log_user 'alice', 'foo'
    vote1 = create_token_vote

    assert_notifications 'blocknotify' => @min_conf do
      txid = @network.send_to_address(vote1.address, 1.2)
      @network.generate(@min_conf)
    end
    vote1.reload
    assert_equal vote1.amount_unconf, 0.0
    assert_equal vote1.amount_conf, 1.2
  end

  def test_blocknotify_after_confirmations_of_multiple_txs
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    vote2 = create_token_vote
    min_conf = vote1.token_type.min_conf

    assert_notifications 'blocknotify' => (min_conf+1) do
      txid1 = @network.send_to_address(vote1.address, 0.7)
      @network.generate(1)
      txid2 = @network.send_to_address(vote1.address, 0.2)
      @network.generate(1)
      txid3 = @network.send_to_address(vote1.address, 1.1)
      txid4 = @network.send_to_address(vote2.address, 0.5)
      @network.generate(1)
      txid5 = @network.send_to_address(vote2.address, 0.15)
      @network.generate(min_conf-2)
    end
    [vote1, vote2].map(&:reload)
    assert_equal vote1.amount_unconf, 1.1
    assert_equal vote1.amount_conf, 0.9
    assert_equal vote2.amount_unconf, 0.65
    assert_equal vote2.amount_conf, 0.0
  end

  def test_issue_edit_hook_and_expiration_should_update_vote_status_scope
    log_user 'alice', 'foo'

    # Resolve issue1 between 8.days and 8.days+1.minute
    # #0 - completed: 0 - 1.month
    # #1 - expired: 1.day - 8.days
    # #2 - completed: 1.day+1.minute - 8.days+1.minute
    # #3 - expired: 1.week-1.minute - 8.days-1.minute
    # #4 - issue2, active: 7.days-14.days
    # #5 - issue2, expired: 7.days-8.days
    votes = []
    [
      [@issue1, 0,                1.month], #0
      [@issue1, 1.day,            1.week], #1
      [@issue1, 1.day+5.seconds,  issue_statuses(:resolved)],
      [@issue1, 1.day+1.minute,   1.week], #2
      [@issue1, 1.week-1.minute,  1.day], #3
      [@issue1, 1.week-5.seconds, issue_statuses(:pulled)],
      [@issue2, 1.week,           1.week], #4
      [@issue2, 1.week,           1.day], #5
      [@issue2, 1.week+1.minute,  issue_statuses(:pulled)],
      [@issue1, 8.days+5.seconds, issue_statuses(:closed)],
    ].each do |issue, t, value|
      travel(t) do
        if value.kind_of?(IssueStatus)
          update_issue_status(issue, value)
        else
          votes << create_token_vote(issue, duration: value)
        end
      end
    end

    travel(8.days+30.seconds) do
      assert_equal @issue1.token_votes.active.map(&:id),
        []
      assert_equal @issue1.token_votes.completed.map(&:id).sort,
        [votes[0].id, votes[2].id].sort
      assert_equal @issue1.token_votes.expired.map(&:id).sort,
        [votes[1].id, votes[3].id].sort
 
      assert_equal @issue2.token_votes.active.map(&:id),
        [votes[4].id]
      assert_equal @issue2.token_votes.completed.map(&:id),
        []
      assert_equal @issue2.token_votes.expired.map(&:id),
        [votes[5].id]
    end

    # TODO: get /my/token_votes page and check for valid content
  end

  def test_issue_edit_hook_should_not_create_payouts_without_votes
    log_user 'alice', 'foo'

    assert_difference 'TokenPayout.count', 0 do
      update_issue_status(@issue1, issue_statuses(:closed))
    end
  end

  def test_issue_edit_hook_should_not_create_payouts_for_not_funded_vote
    log_user 'alice', 'foo'
    vote1 = create_token_vote

    assert_difference 'TokenPayout.count', 0 do
      update_issue_status(@issue1, issue_statuses(:closed))
    end
  end

  def test_issue_edit_hook_should_not_create_payouts_for_funded_unconfirmed_vote
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    fund_token_vote(vote1, 0.25, @min_conf-1)

    assert_difference 'TokenPayout.count', 0 do
      update_issue_status(@issue1, issue_statuses(:closed))
    end
  end

  def test_issue_edit_hook_should_create_payouts_for_funded_confirmed_vote
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    fund_token_vote(vote1, 0.25, @min_conf)

    assert_difference 'TokenPayout.count', 1 do
      update_issue_status(@issue1, issue_statuses(:closed))
    end
  end

  def test_issue_edit_hook_computes_payouts_per_user_share
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    fund_token_vote(vote1, 0.25, @min_conf)
    update_issue_status(@issue1, issue_statuses(:resolved))
    logout_user

    log_user 'bob', 'foo'
    update_issue_status(@issue1, issue_statuses(:pulled))
    logout_user

    log_user 'charlie', 'foo'
    assert_difference 'TokenPayout.count', 3 do
      update_issue_status(@issue1, issue_statuses(:closed))
    end

    assert_equal 0.175, TokenPayout.find_by(payee: users(:alice)).amount
    assert_equal 0.050, TokenPayout.find_by(payee: users(:bob)).amount
    assert_equal 0.025, TokenPayout.find_by(payee: users(:charlie)).amount
  end
end

