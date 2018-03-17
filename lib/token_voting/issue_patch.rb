module TokenVoting
  module IssuePatch
    Issue.class_eval do
      has_many :token_votes, :dependent => :nullify
    end
  end
end

