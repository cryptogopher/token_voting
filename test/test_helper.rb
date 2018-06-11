# Load the Redmine helper
require File.expand_path(File.dirname(__FILE__) + '/../../../test/test_helper')
require 'webrick'

ActiveRecord::FixtureSet.create_fixtures(File.dirname(__FILE__) + '/fixtures/',
  [
    :issues,
    :issue_statuses,
    :users,
    :email_addresses,
    :token_votes,
    :token_payouts,
    :journals,
    :journal_details,
    :projects,
    :roles,
    :members,
    :member_roles,
    :enabled_modules
  ])

def setup_plugin
  Setting.plugin_token_voting = {
    'default_token' => 'BTCREG',
    'BTCREG' => {
      'rpc_uri' => 'http://regtest:7nluWvQfpWTewrCXpChUkoRShigXs29H@172.17.0.1:10482',
      'min_conf' => '6'
    },
    'BTCTEST' => {
      'rpc_uri' => 'http://regtest:7nluWvQfpWTewrCXpChUkoRShigXs29H@172.17.0.1:10482',
      'min_conf' => '6'
    },
    'checkpoints' => {
      'statuses' => [[issue_statuses(:resolved).id.to_s],
                     [issue_statuses(:pulled).id.to_s],
                     [issue_statuses(:closed).id.to_s]],
    'shares' => ['0.7', '0.2', '0.1']
    }
  }
end

def update_issue_status(issue, user, status, &block)
  with_current_user user do
    journal = issue.init_journal(user)
    issue.status = status
    issue.save!
    TokenVote.issue_edit_hook(issue, journal)
    issue.clear_journal
  end
end

def TokenVote.generate!(attributes={})
  tv = TokenVote.new(attributes)
  tv.voter ||= User.take
  tv.issue ||= Issue.take
  tv.duration ||= 1.month
  tv.token ||= :BTCREG
  yield tv if block_given?
  tv.generate_address
  tv.save!
  tv
end

def logout_user
  post signout_path
end

def create_token_vote(issue=issues(:issue_01), attributes={})
  attributes[:token] ||= 'BTCREG'
  attributes[:duration] ||= 1.day

  assert_difference 'TokenVote.count', 1 do
    post "#{issue_token_votes_path(issue)}.js", params: { token_vote: attributes }
  end
  assert_nil flash[:error]
  assert_response :ok

  TokenVote.last
end

module TokenVoting
  class NotificationIntegrationTest < Redmine::IntegrationTest
    # Forces all threads to share the same connection. Necessary for
    # running notifications through webrick, because it starts separate thread.
    # source: https://gist.github.com/josevalim/470808
    class ActiveRecord::Base
      mattr_accessor :shared_connection
      @@shared_connection = nil

      def self.connection
        @@shared_connection || retrieve_connection
      end
    end
    ActiveRecord::Base.shared_connection = ActiveRecord::Base.connection
    # Forces exclusive access to same connection - race conditions happen
    # when multiple threads use same connection simultaneously.
    raise "adapter was expected to be mysql2" unless
      ActiveRecord::Base.connection.adapter_name.downcase == "mysql2"
    module MutexLockedQuerying
      @@semaphore = Mutex.new

      def query(*)
        @@semaphore.synchronize { super }
      end
    end
    Mysql2::Client.prepend(MutexLockedQuerying)
    # Alternatively transactional fixtures can be disabled with some
    # additional magic applied (didn't make it to work :/ ).
    #self.use_transactional_fixtures = false

    def initialize(*args)
      super

      @notifications = Hash.new(0)
      ActiveSupport::Notifications.subscribe 'process_action.action_controller' do |*args|
        data = args.extract_options!
        @notifications[data[:action]] += 1 if data[:controller] == 'TokenVotesController'
      end

      # Setup server for receiving notifications (application server is not running
      # during tests).
      server = WEBrick::HTTPServer.new(
        Port: 3000,
        Logger: WEBrick::Log.new("/dev/null"),
        AccessLog: []
      )
      server.mount_proc '/' do |req, resp|
        headers = {}
        req.header.each { |k,v| v.each { |a| headers[k] = a } }
        resp = self.get req.path, {}, headers
      end
      @t = Thread.new {
        server.start
      }
      Minitest.after_run do
        @t.kill
        @t.join
      end
      Timeout.timeout(5) do
        sleep 0.1 until server.status == :Running
      end
    end

    # Waits for expected number of notifications to occur with regard to timeout.
    # Also checks if there were no superfluous notifications after completion.
    def assert_notifications(expected={})
      timeout=2
      wait_after=0.5
      @notifications.clear
      yield
      Timeout.timeout(timeout) do
        sleep 0.1 until expected.all? { |k,v| @notifications[k] >= v }
      end
      # catch superfluous notifications if any
      sleep wait_after
      assert_operator expected, :<=, @notifications
    end
  end
end

