class AddStatusToTokenVotes < ActiveRecord::Migration
  def change
    add_column :token_votes, :status, :integer
  end
end

