class TokenVotesController < ApplicationController
  unloadable

  before_filter :find_issue, :authorize, :only => [:create]
  before_filter :find_token_vote, :authorize, :only => [:destroy]

  def create
    @token_vote = TokenVote.new(token_vote_params)
    print token_vote_params
    @token_vote.user = User.current
    @token_vote.issue = @issue
    @token_vote.save

    respond_to do |format|
      format.html { redirect_to issue_path(@issue) }
      format.js { @issue.token_votes.reload }
    end
  end

  def destroy
    raise Unauthorized unless @token_vote.deletable?
    @issue = @token_vote.issue
    @token_vote.destroy

    respond_to do |format|
      format.html { redirect_to issue_path(@issue) }
      format.js { @issue.token_votes.reload }
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

