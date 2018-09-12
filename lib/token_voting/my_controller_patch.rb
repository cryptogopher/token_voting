module TokenVoting
  module MyControllerPatch
    MyController.class_eval do
      MY_TOKEN_VOTES_TABS = [
        { name: 'active',
          partial: 'my/token_votes/index',
          label: :label_active_votes },
        { name: 'available',
          partial: 'my/token_votes/available_tokens',
          label: :label_available_tokens },
        { name: 'completed',
          partial: 'my/token_votes/index',
          label: :label_completed_votes },
        { name: 'withdrawals',
          partial: 'my/token_votes/index',
          label: :label_token_withdrawals },
      ]

      def token_votes
        @token_votes = Hash.new([])
        [:active, :expired, :completed].each do |status|
          @token_votes[status.to_s] = TokenVote.where(voter: User.current).send(status)
        end

        @token_votes_tabs = MY_TOKEN_VOTES_TABS
      end
    end
  end
end

