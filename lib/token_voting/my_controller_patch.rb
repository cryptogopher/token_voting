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
        @my_votes = TokenVote.where(voter: User.current).includes(:token_type, :issue, :voter)

        # My tokens
        @my_payouts = TokenPayout.where(payee: User.current)
        @my_expired_votes = @my_votes.expired.funded.includes(:token_type, :issue)

        # My withdrawals
        @my_withdrawals = TokenWithdrawal.where(payee: User.current)
          .includes(:token_type, :token_transaction)
        @token_withdrawal = TokenWithdrawal.new

        if User.current.allowed_to_globally?(:manage_token_votes)
          @my_tabs += MY_ADMIN_TABS
          @requested_withdrawals = TokenWithdrawal.requested.includes(:token_type, :payee)
          @transactions = TokenTransaction.all.includes(:token_withdrawals)
        end
      end
    end
  end
end
