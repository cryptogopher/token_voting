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

  def test_amount_update_on_walletinotify_and_blocknotify
    # For these tests to be executed successfully bitcoind regtest daemon must be
    # configured with 'walletnotify' and 'blocknotify' options properly.
    log_user 'alice', 'foo'

    assert_notifications({'blocknotify' => 5}) do
      @rpc.generate(5)
    end

    create_token_vote
  end
end

