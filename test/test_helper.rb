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
    :journal_details
  ])

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

