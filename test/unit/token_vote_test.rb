require File.expand_path('../../test_helper', __FILE__)

class TokenVoteTest < ActiveSupport::TestCase
  fixtures :issues, :issue_statuses, :users, :email_addresses, :token_votes, :token_payouts,
    :trackers, :projects,
    :journals, :journal_details

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
        'shares' => ['0.7', '0.2', '0.1']
      }
    }
  end

  def test_3_checkpoints_forward_stepwise_processing_1_vote
    issue = issues(:issue_01)
    TokenVote.generate!( {issue: issue, amount_conf: 1.0} )

    assert_no_difference 'TokenPayout.count' do
      update_issue_status(issue, users(:alice), issue_statuses(:resolved))
    end
    assert_no_difference 'TokenPayout.count' do
      update_issue_status(issue, users(:bob), issue_statuses(:pulled))
    end
    assert_difference 'TokenPayout.count', 3 do
      update_issue_status(issue, users(:charlie), issue_statuses(:closed))
    end

    assert_equal TokenPayout.find_by(payee_id: users(:alice)).amount, 0.7
    assert_equal TokenPayout.find_by(payee_id: users(:bob)).amount, 0.2
    assert_equal TokenPayout.find_by(payee_id: users(:charlie)).amount, 0.1
  end
end

