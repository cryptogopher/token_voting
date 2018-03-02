class RemoveRefundAddressFromTokenVotes < ActiveRecord::Migration
  def change
    remove_column :token_votes, :refund_address, :string
  end
end
