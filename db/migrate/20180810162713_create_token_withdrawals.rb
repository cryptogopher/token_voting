class CreateTokenWithdrawals < ActiveRecord::Migration
  def change
    create_table :token_withdrawals do |t|
      t.references :payee, foreign: true, index: true
      t.references :token_type, foreign: true, index: true
      t.decimal :amount, precision: 20, scale: 10
      t.string :txid
      t.string :address
      t.boolean :is_processed
    end
  end
end
