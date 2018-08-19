class TokenVotesController < ApplicationController

  before_filter :find_issue, only: [:create]
  before_filter :find_token_vote, only: [:destroy]
  before_filter :authorize, only: [:create, :destroy]
  before_filter :authorize_global, only: [:withdraw]
  accept_api_auth :walletnotify, :blocknotify

  helper IssuesHelper

  def create
    @token_vote = TokenVote.new(token_votes_params)
    @token_vote.voter = User.current
    @token_vote.issue = @issue
    @token_vote.generate_address
    @token_vote.save!
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid,
         RPC::Error, TokenVote::Error => e
    flash[:error] = e.message
  ensure
    respond_to do |format|
      format.js {
        @token_votes = @issue.reload.token_votes.select {|tv| tv.visible?}
      }
    end
  end

  def destroy
    @token_vote.destroy

    respond_to do |format|
      format.js {
        @token_votes = @issue.reload.token_votes.select {|tv| tv.visible?}
      }
    end
  end

  def withdraw
    @token_withdrawal = TokenWithdrawal.new(token_withdrawal_params)
    @token_withdrawal.payee = User.current
    @token_withdrawal.save!
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
    flash[:error] = e.message
  ensure
    respond_to do |format|
      format.js {
        @token_withdrawals = User.current.reload.token_withdrawals
      }
    end
  end

  # Callback for tx notification, details in token_votes_test.rb
  # (bitcoind --walletnotify cmdline option)
  def walletnotify
    service_api_request {
      token_type = TokenType.find_by_name!(params[:token_type_name])
      TokenVote.process_tx(token_type, params[:txid])
    }
  end

  # Callback for block notification
  # (bitcoind --blocknotify cmdline option)
  def blocknotify
    service_api_request {
      token_type = TokenType.find_by_name!(params[:token_type_name])
      TokenVote.process_block(token_type, params[:blockhash])
    }
  end

  private

  def service_api_request
    yield
  rescue RPC::Error => e
    api_message = e.message
    api_status = :service_unavailable
  rescue ActiveRecord::RecordNotFound => e
    api_message = e.message
    api_status = :bad_request
  ensure
    respond_to do |format|
      format.api {
        render text: (api_message || ''), status: (api_status || :ok), layout: nil
      }
    end
  end

  def token_votes_params
    params.require(:token_vote).permit(:token_type_id, :duration)
  end

  def token_withdrawal_params
    params.require(:token_withdrawal).permit(:token_type_id, :amount, :address)
  end

  # :find_* methods are called before :authorize,
  # @project is required for :authorize to succeed
  def find_issue
    @issue = Issue.find(params[:issue_id])
    raise Unauthorized unless @issue.visible?
    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_token_vote
    @token_vote = TokenVote.find(params[:id])
    raise Unauthorized unless @token_vote.deletable?
    @issue = @token_vote.issue
    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end

