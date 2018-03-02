class RemoveRefundTxidFromTokenVotes < ActiveRecord::Migration
  def change
    remove_column :token_votes, :refund_txid, :string
  end
end
