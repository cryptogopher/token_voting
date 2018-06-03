require File.expand_path('../../test_helper', __FILE__)

class TokenVotesNotifyTest < Redmine::IntegrationTest
  fixtures :issues, :issue_statuses, :users,
    :projects, :roles, :members, :member_roles, :enabled_modules

  # Waits for expected number of notifications to occur with regard to timeout.
  # Also checks if there were no superfluous notifications after completion.
  def wait_for_notifications(expected={}, timeout=10, wait_after=0.1)
    time_end = Time.current + timeout
    while expected.any? { |k,v| @notifications[k] < v } && Time.current < time_end do
      sleep 0.1
    end
    # catch superfluous notifications if any
    sleep wait_after
  end

  def setup
    setup_plugin

    @notifications = Hash.new(0)
    ActiveSupport::Notifications.subscribe 'process_action.action_controller' do |*args|
      data = args.extract_options!
      @notifications[data[:action]] += 1 if data[:controller] == 'TokenVotesController'
      puts data
    end

    @rpc = RPC.get_rpc('BTCREG')
  end

  def finalize
    logout_user
  end

  def test_amount_update_on_walletinotify_and_blocknotify
    # For these tests to be executed successfully bitcoind regtest daemon must be
    # configured with 'walletnotify' and 'blocknotify' options properly.
    log_user 'alice', 'foo'

    assert_difference '@notifications["blocknotify"]', 101 do
      @rpc.generate(101)
      wait_for_notifications({"blocknotify" => 101})
    end

    create_token_vote
  end
end

