class CreateTokenVotes < ActiveRecord::Migration
  def change
    create_table :token_votes do |t|
      t.references :user, foreign: true, index: true
      t.references :issue, foreign: true, index: true
      t.integer :duration
      t.datetime :expiration
      t.string :address
      t.string :txid
      t.string :refund_address
      t.string :refund_txid
      t.integer :token
      t.decimal :amount, precision: 20, scale: 10
    end
  end
end
