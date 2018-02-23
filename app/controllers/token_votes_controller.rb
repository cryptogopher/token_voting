class TokenVotesController < ApplicationController
  unloadable

  before_filter :find_issue, :authorize, :only => [:create]
  before_filter :find_token_vote, :only => [:destroy]
  accept_api_auth :walletnotify

  rescue_from 'RPC::Error' do |e|
    flash[:error] = "Wallet RPC call error: #{e.message}"
    @api_status = :service_unavailable
  end
  rescue_from 'TokenVote::Error' do |e|
    flash[:error] = "TokenVote method error: #{e.message}"
    @api_status = :bad_request
  end

  def create
    @token_vote = TokenVote.new(token_vote_params)
    @token_vote.user = User.current
    @token_vote.issue = @issue
    @token_vote.generate_address
    @token_vote.save

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

  # Executed when wallet tx changes (bitcoind --walletnotify cmdline option)
  def walletnotify
    TokenVote.update_amounts_by_txid(params[:token], params[:txid])
  ensure
    respond_to do |format|
      format.api {
        render text: flash['error'] || '', status: @api_status || :ok, layout: nil
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

