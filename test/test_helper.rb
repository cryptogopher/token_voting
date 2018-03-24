# Load the Redmine helper
require File.expand_path(File.dirname(__FILE__) + '/../../../test/test_helper')

def id(sym)
  ActiveRecord::FixtureSet.identify(sym)
end

ActiveRecord::FixtureSet.create_fixtures(File.dirname(__FILE__) + '/fixtures/',
  [
    :users,
    :issues,
    :issue_statuses,
    :token_votes,
    :token_payouts,
    :journals,
    :journal_details
  ])

