require File.expand_path('../../test_helper', __FILE__)

class TokenVotesNotifyTest < TokenVoting::NotificationIntegrationTest
  fixtures :token_types, :issues, :issue_statuses, :users,
    :projects, :roles, :members, :member_roles, :enabled_modules,
    :trackers, :workflow_transitions

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
    # TODO: get issue page and check for valid content
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

    # cannot destroy if funded with unconfirmed tx
    assert_notifications 'walletnotify' => 1, 'blocknotify' => 0 do
      @network.send_to_address(vote2.address, 0.2)
    end
    vote2.reload
    assert_equal vote2.amount_unconf, 0.2
    assert_no_difference 'TokenVote.count' do
      delete "#{token_vote_path(vote2)}.js"
    end
    assert_response :forbidden

    # cannot destroy if funded with confirmed tx
    min_conf = vote2.token_type.min_conf
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
    # TODO: get issue page and check for valid content
  end

  def test_amount_conf_amount_unconf_update_on_walletnotify_and_blocknotify
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
      @network.send_to_address(vote1.address, 1.0)
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
      @network.send_to_address(vote1.address, 0.5)
      @network.send_to_address(vote2.address, 2.33)
    end
    [vote1, vote2].map(&:reload)
    assert_equal vote1.amount_unconf, 1.5
    assert_equal vote1.amount_conf, 0
    assert_equal vote2.amount_unconf, 2.33

    # walletnotify on additional confirmations incl. different vote
    # amount unconfirmed untill min_conf blocks
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

  def test_amount_in_update_on_blocknotify
    log_user 'alice', 'foo'
    vote1 = create_token_vote

    # don't count unless confirmed
    assert_operator min_conf = vote1.token_type.min_conf, :>, 2
    assert_notifications 'blocknotify' => 1 do
      @network.send_to_address(vote1.address, 1.45)
      @network.generate(1)
    end
    vote1.reload
    assert_equal 0, vote1.amount_in
    assert_equal 1.45, vote1.amount_unconf

    assert_notifications 'blocknotify' => min_conf-2 do
      @network.generate(min_conf-2)
    end
    vote1.reload
    assert_equal 0, vote1.amount_in
    assert_equal 0, vote1.amount_conf

    # count after confirmation
    assert_notifications 'blocknotify' => 1 do
      @network.generate(1)
    end
    vote1.reload
    assert_equal vote1.amount_in, 1.45

    # don't count outgoing transfers
    assert_notifications 'blocknotify' => min_conf do
      @network.send_to_address(vote1.address, 0.12)
      @wallet.send_to_address(@network.get_new_address, 0.6, '', '', true)
      @network.generate(min_conf)
    end
    vote1.reload
    assert_equal 1.57, vote1.amount_in
    assert_equal 0.97, vote1.amount_conf
  end

  def test_status_after_time_and_issue_status_change
    log_user 'alice', 'foo'
    issue1 = issues(:issue_01)
    issue2 = issues(:issue_02)

    # Resolve issue1 between 8.days and 8.days+1.minute
    # #0 - completed: 0 - 1.month
    # #1 - expired: 1.day - 8.days
    # #2 - completed: 1.day+1.minute - 8.days+1.minute
    # #3 - expired: 1.week-1.minute - 8.days-1.minute
    # #4 - issue2, active: 7.days-14.days
    # #5 - issue2, expired: 7.days-8.days
    votes = []
    [
      [issue1, 0,                1.month], #0
      [issue1, 1.day,            1.week], #1
      [issue1, 1.day+5.seconds,  issue_statuses(:resolved)],
      [issue1, 1.day+1.minute,   1.week], #2
      [issue1, 1.week-1.minute,  1.day], #3
      [issue1, 1.week-5.seconds, issue_statuses(:pulled)],
      [issue2, 1.week,           1.week], #4
      [issue2, 1.week,           1.day], #5
      [issue2, 1.week+1.minute,  issue_statuses(:pulled)],
      [issue1, 8.days+5.seconds, issue_statuses(:closed)],
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
      assert_equal issue1.token_votes.active.map(&:id),
        []
      assert_equal issue1.token_votes.completed.map(&:id).sort,
        [votes[0].id, votes[2].id].sort
      assert_equal issue1.token_votes.expired.map(&:id).sort,
        [votes[1].id, votes[3].id].sort
 
      assert_equal issue2.token_votes.active.map(&:id),
        [votes[4].id]
      assert_equal issue2.token_votes.completed.map(&:id),
        []
      assert_equal issue2.token_votes.expired.map(&:id),
        [votes[5].id]
    end

    # TODO: get /my/token_votes page and check for valid content
  end
end

