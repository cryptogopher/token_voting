require File.expand_path('../../test_helper', __FILE__)

class TokenVotesNotifyTest < TokenVoting::NotificationIntegrationTest
  fixtures :issues, :issue_statuses, :users,
    :projects, :roles, :members, :member_roles, :enabled_modules

  def setup
    super
    setup_plugin

    @rpc = RPC.get_rpc('BTCREG')
  end

  def teardown
    super
    logout_user
  end

  def test_amount_update_on_walletnotify_and_blocknotify
    # For these tests to be executed successfully bitcoind regtest daemon must be
    # configured with 'walletnotify' and 'blocknotify' options properly.
    log_user 'alice', 'foo'

    # First coinbase output is spendable after 100 confirmations.
    assert_notifications 'blocknotify' => 101 do
      @rpc.generate(101)
    end

    vote = create_token_vote
    assert_notifications 'walletnotify' => 2 do
      @rpc.send_to_address(vote.address, 1.0)
    end
    vote.reload
    assert_equal vote.amount_unconf, 1.0
    assert_equal vote.amount_conf, 0
  end
end

