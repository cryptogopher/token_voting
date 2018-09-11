class ChangeTxColumnToTextInTokenTransactions < ActiveRecord::Migration
  def change
    change_column :token_transactions, :tx, :text
  end
end
