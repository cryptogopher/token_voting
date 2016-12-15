class CreateBitcoinVotes < ActiveRecord::Migration
  def change
    create_table :bitcoin_votes do |t|
      t.references :issue, index: true, foreign_key: true, null: false
      t.references :user, index: true, foreign_key: true
      t.datetime :exipration
    end
  end
end
