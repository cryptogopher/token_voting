class AddCompletedToTokenVotes < ActiveRecord::Migration
  def change
    add_column :token_votes, :completed, :boolean
  end
end
