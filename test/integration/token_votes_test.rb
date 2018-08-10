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
  end

  def teardown
    super
    logout_user
  end

  def test_create_token_vote_by_anonymous_should_fail
    logout_user
    assert_no_difference 'TokenVote.count' do
      post "#{issue_token_votes_path(@issue1)}.js", params: {
        token_vote: { token: 'BTCREG', duration: 1.day }
      }
    end
    assert_response :unauthorized
  end

  def test_create_token_vote_without_permissions_should_fail
    roles = users(:alice).members.find_by(project: @issue1.project_id).roles
    roles.each { |role| role.remove_permission! :manage_token_votes }

    log_user 'alice', 'foo'
    assert_no_difference 'TokenVote.count' do
      post "#{issue_token_votes_path(@issue1)}.js", params: {
        token_vote: { token: 'BTCREG', duration: 1.day }
      }
    end
    assert_response :forbidden
  end

  def test_create_token_vote
    log_user 'alice', 'foo'
    create_token_vote
    # TODO: get issue page and check for valid content
  end

  def test_destroy_token_vote_by_anonymous_shoulf_fail
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    logout_user

    assert_no_difference 'TokenVote.count' do
      delete "#{token_vote_path(vote1)}.js"
    end
    assert_response :unauthorized
  end

  def test_destroy_token_vote_by_non_owner_should_fail
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    logout_user

    log_user 'bob', 'foo'
    assert_no_difference 'TokenVote.count' do
      delete "#{token_vote_path(vote1)}.js"
    end
    assert_response :forbidden
  end

  def test_destroy_token_vote_without_permissions_should_fail
    log_user 'alice', 'foo'
    vote1 = create_token_vote

    roles = users(:alice).members.find_by(project: @issue1.project_id).roles
    roles.each { |role| role.remove_permission! :manage_token_votes }

    assert_no_difference 'TokenVote.count' do
      delete "#{token_vote_path(vote1)}.js"
    end
    assert_response :forbidden
  end

  # TODO: test for destruction without issue visibility

  def test_destroy_token_vote_funded_with_unconfirmed_tx_should_fail
    log_user 'alice', 'foo'
    vote1 = create_token_vote

    assert_notifications 'walletnotify' => 1, 'blocknotify' => 0 do
      txid = @network.send_to_address(vote1.address, 0.2)
      assert_in_mempool @wallet, txid
    end
    vote1.reload
    assert_equal vote1.amount_unconf, 0.2
    assert_no_difference 'TokenVote.count' do
      delete "#{token_vote_path(vote1)}.js"
    end
    assert_response :forbidden
  end

  def test_destroy_token_vote_funded_with_confirmed_tx_should_fail
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

  def test_destroy_token_vote
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    destroy_token_vote(vote1)
    # TODO: get issue page and check for valid content
  end

  def test_blocknotify_and_walletnotify_update_amount_conf_and_amount_unconf
    # For these tests to be executed successfully bitcoind regtest daemon must be
    # configured with 'walletnotify' and 'blocknotify' options properly.
    # 'walletnotify' occurs after:
    #  * first receiving a payment
    #  * first confirmation on the payment
    #  * you send a payment
    
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    vote2 = create_token_vote

    # walletnotify on receiving payment
    assert_notifications 'walletnotify' => 1, 'blocknotify' => 0 do
      txid = @network.send_to_address(vote1.address, 1.0)
      assert_in_mempool @wallet, txid
    end
    [vote1, vote2].map(&:reload)
    assert_equal vote1.amount_unconf, 1.0
    assert_equal vote1.amount_conf, 0
    assert_equal vote2.amount_unconf, 0

    # walletnotify on 1st confirmation
    # blocknotify on new block
    assert_notifications 'walletnotify' => 1, 'blocknotify' => 1 do
      @network.generate(1)
    end
    [vote1, vote2].map(&:reload)
    assert_equal vote1.amount_unconf, 1.0
    assert_equal vote1.amount_conf, 0
    assert_equal vote2.amount_unconf, 0

    # walletnotify on additional payments incl. different vote
    assert_notifications 'walletnotify' => 2, 'blocknotify' => 0 do
      txid1 = @network.send_to_address(vote1.address, 0.5)
      txid2 = @network.send_to_address(vote2.address, 2.33)
      assert_in_mempool @wallet, txid1, txid2
    end
    [vote1, vote2].map(&:reload)
    assert_equal vote1.amount_unconf, 1.5
    assert_equal vote1.amount_conf, 0
    assert_equal vote2.amount_unconf, 2.33

    # walletnotify on additional confirmations incl. different vote
    # amount unconfirmed until min_conf blocks
    min_conf = vote1.token_type.min_conf
    assert_operator min_conf, :>, 2
    assert_notifications 'walletnotify' => 2, 'blocknotify' => (min_conf-2) do
      @network.generate(min_conf-2)
    end
    [vote1, vote2].map(&:reload)
    assert_equal vote1.amount_unconf, 1.5
    assert_equal vote1.amount_conf, 0
    assert_equal vote2.amount_unconf, 2.33

    # amount confirmed after min_conf blocks
    assert_notifications 'walletnotify' => 0, 'blocknotify' => 1 do
      @network.generate(1)
    end
    [vote1, vote2].map(&:reload)
    assert_equal vote1.amount_unconf, 0.5
    assert_equal vote1.amount_conf, 1.0
    assert_equal vote2.amount_unconf, 2.33

    # all funds confirmed after enough blocks
    assert_notifications 'walletnotify' => 0, 'blocknotify' => (min_conf*2) do
      @network.generate(min_conf*2)
    end
    [vote1, vote2].map(&:reload)
    assert_equal vote1.amount_unconf, 0
    assert_equal vote1.amount_conf, 1.5
    assert_equal vote2.amount_conf, 2.33
  end

  def test_status_after_time_and_issue_status_change
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
          votes << create_token_vote(issue, {duration: value})
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

  def test_rpc_get_tx_addresses
    address = @wallet.get_new_address
    txid = nil
    assert_notifications 'blocknotify' => 1 do
      txid = @network.send_to_address(address, 0.1)
      @network.generate(1)
    end
    assert txid
    inputs, outputs = @wallet.get_tx_addresses(txid)
    assert_operator 0, :<, inputs.length
    assert_includes [1, 2], outputs.length
    assert_includes outputs, address
  end

  def test_rpc_send_from_address
    log_user 'alice', 'foo'
    vote1 = create_token_vote
    vote2 = create_token_vote

    assert_operator min_conf = vote1.token_type.min_conf, :>, 2
    assert_notifications 'blocknotify' => min_conf do
      @network.send_to_address(vote1.address, 1.45)
      @network.generate(min_conf)
    end
    [vote1, vote2].map(&:reload)
    assert_equal 0, vote1.amount_unconf
    assert_equal 1.45, vote1.amount_conf

    assert_notifications 'blocknotify' => min_conf do
      txid = @wallet.send_from_address(vote1.address, vote2.address, 0.6)
      assert_in_mempool @network, txid
      @network.send_to_address(vote1.address, 0.12)
      @network.generate(min_conf)
    end
    [vote1, vote2].map(&:reload)
    assert_equal 0.97, vote1.amount_conf
    assert_equal 0.599, vote2.amount_conf
  end
end

