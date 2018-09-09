class RenameTxidToNtxidInTokenTransactions < ActiveRecord::Migration
  def change
    rename_column :token_transactions, :txid, :ntxid
  end
end
