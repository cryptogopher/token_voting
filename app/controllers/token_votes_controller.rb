class InvalidToken < Exception; end

class TokenVotesController < ApplicationController
  unloadable

  before_filter :find_issue, :authorize, :only => [:create]
  before_filter :find_token_vote, :authorize, :only => [:destroy]

  def create
    @token_vote = TokenVote.new(token_vote_params)
    @token_vote.user = User.current
    @token_vote.issue = @issue
    @token_vote.generate_address
  rescue RPC::Error => e
    flash[:error] = "Cannot create token vote - RPC error: #{e.message}"
  else
    @token_vote.save
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

  # Executed when wallet tx changes (bitcoind --walletnotify cmdline option)
  def walletnotify
    token = params[:token].to_sym
    raise InvalidToken unless TokenVote.tokens.has_key(token)
    rpc = RPC.get_rpc(token)

    addresses = rpc.get_tx_addresses(params[:txid])
    TokenVote.where(address: addresses).each.update_received_amount

    #add API key auth?
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

