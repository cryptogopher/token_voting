class AddTimestampsToTokenTransactions < ActiveRecord::Migration
  def change
    add_timestamps :token_transactions, null: false
  end
end
