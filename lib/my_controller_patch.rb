module MyControllerPatch
  MyController.class_eval do
    MY_TOKEN_VOTES_TABS = [
      {name: 'active', partial: 'my/token_votes/index', label: :label_active_votes},
      {name: 'completed', partial: 'my/token_votes/index', label: :label_completed_votes},
      {name: 'expired', partial: 'my/token_votes/index', label: :label_expired_votes},
      {name: 'withdrawals', partial: 'my/token_votes/index', label: :label_token_withdrawals},
    ]

    def token_votes
      @token_votes = Hash.new([])
      [:active, :completed, :expired].each do |status|
        @token_votes[status.to_s] = TokenVote.where(voter: User.current).send(status)
      end

      respond_to do |format|
        format.html { @token_votes_tabs = MY_TOKEN_VOTES_TABS }
      end
    end
  end
end

MyController.include MyControllerPatch

