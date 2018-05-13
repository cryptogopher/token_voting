require File.expand_path('../../test_helper', __FILE__)

class TokenVoteTest < ActiveSupport::TestCase
  fixtures :issues, :issue_statuses, :users, :email_addresses, :token_votes, :token_payouts,
    :trackers, :projects,
    :journals, :journal_details

  def setup
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

  def test_forward_stepwise_processing_payouts
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

  def test_forward_stepwise_processing_with_repeating_checkpoint_payouts
    issue = issues(:issue_01)
    TokenVote.generate!( {issue: issue, amount_conf: 1.0} )

    assert_no_difference 'TokenPayout.count' do
      update_issue_status(issue, users(:alice), issue_statuses(:resolved))
    end
    assert_no_difference 'TokenPayout.count' do
      update_issue_status(issue, users(:bob), issue_statuses(:pulled))
    end
    assert_no_difference 'TokenPayout.count' do
      update_issue_status(issue, users(:gopher), issue_statuses(:pulled))
    end
    assert_difference 'TokenPayout.count', 3 do
      update_issue_status(issue, users(:charlie), issue_statuses(:closed))
    end

    assert_equal TokenPayout.find_by(payee_id: users(:alice)).amount, 0.7
    assert_equal TokenPayout.find_by(payee_id: users(:bob)).amount, 0.2
    assert_nil TokenPayout.find_by(payee_id: users(:gopher))
    assert_equal TokenPayout.find_by(payee_id: users(:charlie)).amount, 0.1
  end

  def test_forward_shortcut_processing_payouts
    issue = issues(:issue_01)
    TokenVote.generate!( {issue: issue, amount_conf: 1.0} )

    assert_no_difference 'TokenPayout.count' do
      update_issue_status(issue, users(:alice), issue_statuses(:resolved))
    end
    assert_difference 'TokenPayout.count', 2 do
      update_issue_status(issue, users(:charlie), issue_statuses(:closed))
    end

    assert_equal TokenPayout.find_by(payee_id: users(:alice)).amount, 0.7
    assert_equal TokenPayout.find_by(payee_id: users(:charlie)).amount, 0.3
  end

  def test_partial_backtrack_before_final_checkpoint_payouts
    issue = issues(:issue_01)
    TokenVote.generate!( {issue: issue, amount_conf: 1.0} )

    assert_no_difference 'TokenPayout.count' do
      update_issue_status(issue, users(:alice), issue_statuses(:resolved))
    end
    assert_no_difference 'TokenPayout.count' do
      update_issue_status(issue, users(:bob), issue_statuses(:pulled))
    end
    assert_no_difference 'TokenPayout.count' do
      update_issue_status(issue, users(:charlie), issue_statuses(:resolved))
    end
    assert_no_difference 'TokenPayout.count' do
      update_issue_status(issue, users(:dave), issue_statuses(:pulled))
    end
    assert_difference 'TokenPayout.count', 3 do
      update_issue_status(issue, users(:gopher), issue_statuses(:closed))
    end

    assert_equal TokenPayout.find_by(payee_id: users(:alice)).amount, 0.7
    assert_nil TokenPayout.find_by(payee_id: users(:bob))
    assert_nil TokenPayout.find_by(payee_id: users(:charlie))
    assert_equal TokenPayout.find_by(payee_id: users(:dave)).amount, 0.2
    assert_equal TokenPayout.find_by(payee_id: users(:gopher)).amount, 0.1
  end

  def test_full_backtrack_before_final_checkpoint_payouts
    issue = issues(:issue_01)
    TokenVote.generate!( {issue: issue, amount_conf: 1.0} )

    assert_no_difference 'TokenPayout.count' do
      update_issue_status(issue, users(:bob), issue_statuses(:pulled))
    end
    assert_no_difference 'TokenPayout.count' do
      update_issue_status(issue, users(:charlie), issue_statuses(:new))
    end
    assert_difference 'TokenPayout.count', 1 do
      update_issue_status(issue, users(:gopher), issue_statuses(:closed))
    end

    assert_nil TokenPayout.find_by(payee_id: users(:bob))
    assert_nil TokenPayout.find_by(payee_id: users(:charlie))
    assert_equal TokenPayout.find_by(payee_id: users(:gopher)).amount, 1.0
  end

  def test_partial_backtrack_after_final_checkpoint_payouts
    issue = issues(:issue_01)
    TokenVote.generate!( {issue: issue, amount_conf: 1.0} )

    assert_no_difference 'TokenPayout.count' do
      update_issue_status(issue, users(:alice), issue_statuses(:pulled))
    end
    assert_difference 'TokenPayout.count', 2 do
      update_issue_status(issue, users(:bob), issue_statuses(:closed))
    end
    assert_difference 'TokenPayout.count', -2 do
      update_issue_status(issue, users(:charlie), issue_statuses(:resolved))
    end
    assert_no_difference 'TokenPayout.count' do
      update_issue_status(issue, users(:dave), issue_statuses(:pulled))
    end
    assert_difference 'TokenPayout.count', 3 do
      update_issue_status(issue, users(:gopher), issue_statuses(:closed))
    end

    assert_equal TokenPayout.find_by(payee_id: users(:alice)).amount, 0.7
    assert_nil TokenPayout.find_by(payee_id: users(:bob))
    assert_nil TokenPayout.find_by(payee_id: users(:charlie))
    assert_equal TokenPayout.find_by(payee_id: users(:dave)).amount, 0.2
    assert_equal TokenPayout.find_by(payee_id: users(:gopher)).amount, 0.1
  end

  def test_forward_finalization_in_one_step_payouts
    issue = issues(:issue_01)
    TokenVote.generate!( {issue: issue, amount_conf: 1.0} )

    assert_difference 'TokenPayout.count', 1 do
      update_issue_status(issue, users(:alice), issue_statuses(:closed))
    end

    assert_equal TokenPayout.find_by(payee_id: users(:alice)).amount, 1.0
  end

  def test_zero_valued_share_payouts
    Setting.plugin_token_voting['checkpoints']['shares'] = ['0.6', '0.0', '0.4']

    issue = issues(:issue_01)
    TokenVote.generate!( {issue: issue, amount_conf: 1.0} )

    assert_no_difference 'TokenPayout.count' do
      update_issue_status(issue, users(:alice), issue_statuses(:resolved))
    end
    assert_no_difference 'TokenPayout.count' do
      update_issue_status(issue, users(:bob), issue_statuses(:pulled))
    end
    assert_difference 'TokenPayout.count', 2 do
      update_issue_status(issue, users(:charlie), issue_statuses(:closed))
    end

    assert_equal TokenPayout.find_by(payee_id: users(:alice)).amount, 0.6
    assert_nil TokenPayout.find_by(payee_id: users(:bob))
    assert_equal TokenPayout.find_by(payee_id: users(:charlie)).amount, 0.4
  end

  def test_multiple_checkpoints_by_single_user_payouts
    issue = issues(:issue_01)
    TokenVote.generate!( {issue: issue, amount_conf: 1.0} )

    assert_no_difference 'TokenPayout.count' do
      update_issue_status(issue, users(:alice), issue_statuses(:resolved))
    end
    assert_no_difference 'TokenPayout.count' do
      update_issue_status(issue, users(:bob), issue_statuses(:pulled))
    end
    assert_difference 'TokenPayout.count', 2 do
      update_issue_status(issue, users(:alice), issue_statuses(:closed))
    end

    assert_equal TokenPayout.find_by(payee_id: users(:alice)).amount, 0.8
    assert_equal TokenPayout.find_by(payee_id: users(:bob)).amount, 0.2
  end

  def test_multiple_votes_pauoyts
    issue = issues(:issue_01)
    TokenVote.generate!( {issue: issue, amount_conf: 1.0} )
    TokenVote.generate!( {issue: issue, amount_conf: 0.2} )
    TokenVote.generate!( {issue: issue, amount_conf: 15.0} )

    assert_no_difference 'TokenPayout.count' do
      update_issue_status(issue, users(:alice), issue_statuses(:resolved))
    end
    assert_no_difference 'TokenPayout.count' do
      update_issue_status(issue, users(:bob), issue_statuses(:pulled))
    end
    assert_difference 'TokenPayout.count', 3 do
      update_issue_status(issue, users(:charlie), issue_statuses(:closed))
    end

    assert_equal TokenPayout.find_by(payee_id: users(:alice)).amount, 11.34
    assert_equal TokenPayout.find_by(payee_id: users(:bob)).amount, 3.24
    assert_equal TokenPayout.find_by(payee_id: users(:charlie)).amount, 1.62
  end
  
  def test_multiple_tokens_payouts
    issue = issues(:issue_01)
    TokenVote.generate!( {issue: issue, amount_conf: 1.0, token: :BTCREG} )
    TokenVote.generate!( {issue: issue, amount_conf: 6.0, token: :BTCTEST} )
    TokenVote.generate!( {issue: issue, amount_conf: 0.1, token: :BTCREG} )
    TokenVote.generate!( {issue: issue, amount_conf: 2.0, token: :BTCTEST} )

    assert_no_difference 'TokenPayout.count' do
      update_issue_status(issue, users(:alice), issue_statuses(:resolved))
    end
    assert_no_difference 'TokenPayout.count' do
      update_issue_status(issue, users(:bob), issue_statuses(:pulled))
    end
    assert_difference 'TokenPayout.count', 6 do
      update_issue_status(issue, users(:charlie), issue_statuses(:closed))
    end

    assert_equal TokenPayout.BTCREG.find_by(payee_id: users(:alice)).amount, 0.77
    assert_equal TokenPayout.BTCTEST.find_by(payee_id: users(:alice)).amount, 5.6
    assert_equal TokenPayout.BTCREG.find_by(payee_id: users(:bob)).amount, 0.22
    assert_equal TokenPayout.BTCTEST.find_by(payee_id: users(:bob)).amount, 1.6
    assert_equal TokenPayout.BTCREG.find_by(payee_id: users(:charlie)).amount, 0.11
    assert_equal TokenPayout.BTCTEST.find_by(payee_id: users(:charlie)).amount, 0.8
  end

  def test_expired_vote_payouts
    issue = issues(:issue_01)
    TokenVote.generate!( {issue: issue, amount_conf: 0.25} )
    TokenVote.generate!( {issue: issue, amount_conf: 0.001} )
    TokenVote.generate!( {issue: issue, amount_conf: 2.2} ) do |tv|
      tv.expiration = 1.day.ago
    end

    assert_no_difference 'TokenPayout.count' do
      update_issue_status(issue, users(:alice), issue_statuses(:resolved))
    end
    assert_no_difference 'TokenPayout.count' do
      update_issue_status(issue, users(:bob), issue_statuses(:pulled))
    end
    assert_difference 'TokenPayout.count', 3 do
      update_issue_status(issue, users(:charlie), issue_statuses(:closed))
    end

    assert_equal TokenPayout.BTCREG.find_by(payee_id: users(:alice)).amount, 0.1757
    assert_equal TokenPayout.BTCREG.find_by(payee_id: users(:bob)).amount, 0.0502
    assert_equal TokenPayout.BTCREG.find_by(payee_id: users(:charlie)).amount, 0.0251
  end
end

