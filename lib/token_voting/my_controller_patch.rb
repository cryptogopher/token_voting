module TokenVoting
  module MyControllerPatch
    MyController.class_eval do
      MY_USER_TABS = [
        { name: 'votes',
          partial: 'my/token_votes/votes',
          label: :label_my_votes },
        { name: 'withdrawals',
          partial: 'my/token_votes/withdrawals',
          label: :label_my_withdrawals },
      ]
      MY_ADMIN_TABS = [
        { name: 'payouts',
          partial: 'my/token_votes/payouts',
          label: :label_payouts },
      ]

      def token_votes
        @my_tabs = MY_USER_TABS
        @my_votes = TokenVote.where(voter: User.current)
        @my_expired_votes = @my_votes.expired.funded
        @my_payouts = TokenPayout.where(payee: User.current)
        @my_withdrawals = TokenWithdrawal.where(payee: User.current)

        if User.current.allowed_to_globally?(:manage_token_votes)
          @my_tabs += MY_ADMIN_TABS
        end
      end
    end
  end
end
