require File.expand_path('../../test_helper', __FILE__)

class TokenVoteTest < ActiveSupport::TestCase
  fixtures :issues, :issue_statuses, :users, :token_votes, :token_payouts,
    :journals, :journal_details,
    :trackers, :projects

  def setup
    Setting['plugin_token_voting'] = {
      'default_token' => 'BTCREG',
      'BTCREG' => {
        'rpc_uri' => 'http://regtest:7nluWvQfpWTewrCXpChUkoRShigXs29H@172.17.0.1:10482',
        'min_conf' => '6'
      },
      'checkpoints' => {
        'statuses' => [[issue_statuses(:resolved).id.to_s],
                     [issue_statuses(:pulled).id.to_s],
                     [issue_statuses(:closed).id.to_s]],
        'shares' => ['0.1', '0.9', '0.0']
      }
    }
  end

  def test_3_checkpoints_forward_stepwise_processing
    issue = issues(:issue_01)
    assert_no_difference 'TokenPayout.count' do
      with_current_user users(:alice) do
        journal = issue.init_journal(users(:alice))
        issue.status_id = issue_statuses(:resolved).id
        issue.save!
        TokenVote.issue_edit_hook(issue, journal)
      end
      with_current_user users(:bob) do
        issue.status_id = issue_statuses(:pulled).id
        issue.save!
      end
    end
    assert_difference 'TokenPayout.count', 2 do
      with_current_user users(:charlie) do
        @issue.status = issue_statuses(:closed)
        @issue.save
      end
    end
  end
end

