class RenameUserToVoterInTokenVotes < ActiveRecord::Migration
  def change
    rename_column :token_votes, :user_id, :voter_id
  end
end
