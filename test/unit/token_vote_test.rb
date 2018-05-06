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
        'shares' => ['0.1', '0.0', '0.9']
      }
    }
  end

  def test_3_checkpoints_forward_stepwise_processing_1_vote
    issue = issues(:issue_01)
    #TokenVote.generate!( {issue: issue, expiration: 1.month, token: :BTCREG,
    #                      amount_conf: 1.0} )
    tv = TokenVote.new(voter: User.find_by_login(:bob),
                       issue: issue,
                       duration: 1.month,
                       token: :BTCREG,
                       amount_conf: 1.0)
    tv.generate_address
    tv.save!

    assert_no_difference 'TokenPayout.count' do
      after_issue_status_change(issue, users(:alice), issue_statuses(:resolved)) do |journal|
        TokenVote.issue_edit_hook(issue, journal)
      end
    end
    assert_no_difference 'TokenPayout.count' do
      after_issue_status_change(issue, users(:bob), issue_statuses(:pulled)) do |journal|
        TokenVote.issue_edit_hook(issue, journal)
      end
    end
    assert_difference 'TokenPayout.count', 2 do
      after_issue_status_change(issue, users(:charlie), issue_statuses(:closed)) do |journal|
        TokenVote.issue_edit_hook(issue, journal)
      end
    end
    assert_equal TokenPayout.find_by(payee_id: users(:alice)).amount, 0.1
    assert_equal TokenPayout.find_by(payee_id: users(:charlie)).amount, 0.9
  end
end

