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
    assert_notifications 'walletnotify' => 1, 'blocknotify' => (min_conf-1) do
      @network.generate(min_conf-1)
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

