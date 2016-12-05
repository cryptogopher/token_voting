class CreateBitcoinVotes < ActiveRecord::Migration
  def change
    create_table :bitcoin_votes do |t|
      t.references :issue, index: true, foreign_key: true
      t.datetime :exipration
    end
    add_index :bitcoin_votes, :issue_id
  end
end
