class CreateTokenVotes < ActiveRecord::Migration
  def change
    create_table :token_votes do |t|
      t.references :user
      t.references :issue
      t.datetime :expiration
      t.string :address
      t.string :txid
      t.string :refund_address
      t.string :refund_txid

      t.timestamps null: false
    end
  end
end
