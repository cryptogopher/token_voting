module TokenVoting
  module IssuesControllerPatch
    IssuesController.class_eval do
      before_filter :prepare_token_votes, :only => [:show]

      private
      def prepare_token_votes
        # Need to recompute total stats for issue on #show only
        # TokenVote#create/destroy do not affect amounts
        @token_vote_stats = TokenVote.compute_stats(@issue.token_votes)

        @token_votes = @issue.token_votes.select {|tv| tv.visible?}
        @token_vote = TokenVote.new
      end
    end
  end
end

