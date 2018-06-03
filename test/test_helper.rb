# Load the Redmine helper
require File.expand_path(File.dirname(__FILE__) + '/../../../test/test_helper')

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

def logout_user
  post signout_path
  #request.session.clear
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

def create_token_vote(issue=issues(:issue_01), attributes={})
  attributes[:token] ||= 'BTCREG'
  attributes[:duration] ||= 1.day

  assert_difference 'TokenVote.count', 1 do
    post "#{issue_token_votes_path(issue)}.js", params: { token_vote: attributes }
    assert_nil flash[:error]
  end
  assert_response :ok
end


