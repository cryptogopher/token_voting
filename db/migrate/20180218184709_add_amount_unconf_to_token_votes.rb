class AddAmountUnconfToTokenVotes < ActiveRecord::Migration
  def change
    add_column :token_votes, :amount_unconf, :decimal, precision: 20, scale: 10
  end
end
