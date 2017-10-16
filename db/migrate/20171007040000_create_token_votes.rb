class CreateTokenVotes < ActiveRecord::Migration
  def change
    create_table :token_votes do |t|
      t.references :user
      t.references :issue
      t.integer :duration
      t.datetime :expiration
      t.string :address
      t.string :txid
      t.string :refund_address
      t.string :refund_txid
      t.string :token
      t.decimal :amount, precision: 20, scale: 10

      t.timestamps null: false
    end
  end
end
