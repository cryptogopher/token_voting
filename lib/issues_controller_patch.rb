module IssuesControllerPatch
  IssuesController.class_eval do
    before_filter :prepare_token_votes, :only => [:show]

    private
    def prepare_token_votes
      @token_votes = @issue.token_votes.select {|tv| tv.visible?}
      @token_vote = TokenVote.new

      # Computing total stats for issue
      # No need to recompute stats on TokenVote#create/destroy
      # as these do not affect amounts
      total_stats = Hash.new{|hash, key| hash[key] = Hash.new}
      TokenVote::STAT_PERIODS.values.each do |period|
        # Get guaranteed amount per token in given period
        stats = @issue.token_votes.
          where('expiration > ?', Time.current + period).
          group(:token).
          sum(:amount)
        stats.each do |token_index, amount|
          token_name = TokenVote.tokens.key(token_index)
          total_stats[token_name][period] = amount if amount > 0.0
        end
      end
      @token_vote_stats = total_stats
    end
  end
end

IssuesController.include IssuesControllerPatch
