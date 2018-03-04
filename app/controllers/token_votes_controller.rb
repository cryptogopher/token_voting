class TokenVotesController < ApplicationController
  unloadable

  before_filter :authorize, only: [:my]
  before_filter :find_issue, :authorize, only: [:create]
  before_filter :find_token_vote, only: [:destroy]
  accept_api_auth :walletnotify, :blocknotify

  helper IssuesHelper

  def create
    @token_vote = TokenVote.new(token_vote_params)
    @token_vote.voter = User.current
    @token_vote.issue = @issue
    @token_vote.generate_address
    @token_vote.save

  rescue RPC::Error, TokenVote::Error => e
    flash[:error] = e.message

  ensure
    respond_to do |format|
      format.js {
        @token_votes = @issue.reload.token_votes.select {|tv| tv.visible?}
      }
    end
  end

  def destroy
    raise Unauthorized unless @token_vote.deletable?

    @issue = @token_vote.issue
    @token_vote.destroy

    respond_to do |format|
      format.js {
        @token_votes = @issue.reload.token_votes.select {|tv| tv.visible?}
      }
    end
  end

  # For bitcoind: executed when tx broadcasted and after first confirmation
  # (bitcoind --walletnotify cmdline option)
  def walletnotify
    service_api_request {
      TokenVote.update_txn_amounts(params[:token], params[:txid])
    }
  end

  # For bitcoind: executed when new block is found
  # (bitcoind --blocknotify cmdline option)
  def blocknotify
    service_api_request {
      TokenVote.update_unconfirmed_amounts(params[:token], params[:blockhash])
    }
  end

  MY_TOKEN_VOTES_TABS = [
    {:name => 'active', :partial => 'token_votes/my/index', :label => :label_active_votes},
    {:name => 'resolved', :partial => 'token_votes/my/index', :label => :label_resolved_votes},
    {:name => 'expired', :partial => 'token_votes/my/index', :label => :label_expired_votes},
    {:name => 'withdrawals', :partial => 'token_votes/my/index',
     :label => :label_token_withdrawals},
  ]

  # /my/token_votes
  def my
    @token_votes = Hash.new([])
    [:active, :resolved, :expired].each do |status|
      @token_votes[status.to_s] = TokenVote.where(voter: User.current).send(status)
    end
    
    respond_to do |format|
      format.html { @token_votes_tabs = MY_TOKEN_VOTES_TABS }
    end
  end

  private

  def service_api_request
    yield

  rescue RPC::Error => e
    api_message = e.message
    api_status = :service_unavailable
  rescue TokenVote::Error => e
    api_message = e.message
    api_status = :bad_request

  ensure
    respond_to do |format|
      format.api {
        render text: (api_message || ''), status: (api_status || :ok), layout: nil
      }
    end
  end

  def token_vote_params
    params.require(:token_vote).permit(:token, :duration)
  end

  def find_issue
    @issue = Issue.find(params[:issue_id])
    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_token_vote
    @token_vote = TokenVote.find(params[:id])
    @project = @token_vote.issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end

