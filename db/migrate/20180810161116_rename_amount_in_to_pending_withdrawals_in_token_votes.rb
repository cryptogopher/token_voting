class RenameAmountInToPendingWithdrawalsInTokenVotes < ActiveRecord::Migration
  def change
    rename_column :token_votes, :amount_in, :pending_withdrawals
  end
end
