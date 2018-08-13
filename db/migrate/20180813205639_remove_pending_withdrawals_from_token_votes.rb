class RemovePendingWithdrawalsFromTokenVotes < ActiveRecord::Migration
  def change
    remove_column :token_votes, :pending_withdrawals, :decimal
  end
end
