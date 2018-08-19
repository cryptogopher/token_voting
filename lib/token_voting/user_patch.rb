module TokenVoting
  module UserPatch
    User.class_eval do
      has_many :token_votes, dependent: :nullify, foreign_key: 'voter_id'
      has_many :token_payouts, dependent: :destroy, foreign_key: 'payee_id'
      has_many :token_withdrawals, dependent: :nullify, foreign_key: 'payee_id'
    end
  end
end

