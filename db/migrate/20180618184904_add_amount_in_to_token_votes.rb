class AddAmountInToTokenVotes < ActiveRecord::Migration
  def change
    add_column :token_votes, :amount_in, :decimal, precision: 20, scale: 10
  end
end
