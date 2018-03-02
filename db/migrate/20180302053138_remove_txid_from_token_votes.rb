class RemoveTxidFromTokenVotes < ActiveRecord::Migration
  def change
    remove_column :token_votes, :txid, :string
  end
end
