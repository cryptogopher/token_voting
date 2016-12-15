class AddUserRefToBitcoinVotes < ActiveRecord::Migration
  def change
    add_reference :bitcoin_votes, :user, index: true, foreign_key: true
  end
end
