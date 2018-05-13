module TokenVoting
  module IssuePatch
    Issue.class_eval do
      has_many :token_votes, dependent: :nullify
      has_many :token_payouts, dependent: :destroy
      has_many :journal_details, through: :journals, source: :details
    end
  end
end

