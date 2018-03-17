class AddIsCompletedToTokenVotes < ActiveRecord::Migration
  def change
    add_column :token_votes, :is_completed, :boolean
  end
end
