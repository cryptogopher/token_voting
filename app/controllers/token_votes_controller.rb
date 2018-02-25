class TokenVotesController < ApplicationController
  unloadable

  before_filter :find_issue, :authorize, :only => [:create]
  before_filter :find_token_vote, :only => [:destroy]
  accept_api_auth :walletnotify

  helper IssuesHelper

  def create
    @token_vote = TokenVote.new(token_vote_params)
    @token_vote.user = User.current
    @token_vote.issue = @issue
    @token_vote.generate_address
    @token_vote.save

  rescue RPC::Error, TokenVote::Error => e
    flash[:error] = e.message

  ensure
    respond_to do |format|
      format.html { redirect_to issue_path(@issue) }
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
      format.html { redirect_to issue_path(@issue) }
      format.js {
        @token_votes = @issue.reload.token_votes.select {|tv| tv.visible?}
      }
    end
  end

  # Executed when wallet tx changes (e.g. bitcoind --walletnotify cmdline option)
  def walletnotify
    TokenVote.update_amounts_by_txid(params[:token], params[:txid])

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

  private

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

