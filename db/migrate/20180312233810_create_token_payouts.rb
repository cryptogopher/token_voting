class CreateTokenPayouts < ActiveRecord::Migration
  def change
    create_table :token_payouts do |t|
      t.references :payee, foreign: true, index: true
      t.references :issue, foreign: true, index: true
      t.integer :token
      t.decimal :amount, precision: 20, scale: 10
    end
  end
end
