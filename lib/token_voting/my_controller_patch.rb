module TokenVoting
  module MyControllerPatch
    MyController.class_eval do
      MY_USER_TABS = [
        { name: 'votes',
          partial: 'my/token_votes/votes',
          label: :label_my_votes },
        { name: 'tokens',
          partial: 'my/token_votes/tokens',
          label: :label_my_tokens },
        { name: 'withdrawals',
          partial: 'my/token_votes/withdrawals',
          label: :label_my_withdrawals },
      ]
      MY_ADMIN_TABS = [
        { name: 'transactions',
          partial: 'my/token_votes/transactions',
          label: :label_transactions },
      ]

      def token_votes
        @my_tabs = MY_USER_TABS

        # My votes
        @my_votes = TokenVote.where(voter: User.current)

        # My tokens
        @my_expired_votes = @my_votes.expired.funded
        @my_payouts = TokenPayout.where(payee: User.current)

        # My withdrawals
        @my_withdrawals = TokenWithdrawal.where(payee: User.current)
        @token_withdrawal = TokenWithdrawal.new

        if User.current.allowed_to_globally?(:manage_token_votes)
          @my_tabs += MY_ADMIN_TABS
          @requested_withdrawals = TokenWithdrawal.requested
          @transactions = TokenTransaction.all
        end
      end
    end
  end
end
