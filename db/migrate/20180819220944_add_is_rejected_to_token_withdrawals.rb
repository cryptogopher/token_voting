class AddIsRejectedToTokenWithdrawals < ActiveRecord::Migration
  def change
    add_column :token_withdrawals, :is_rejected, :boolean
  end
end
