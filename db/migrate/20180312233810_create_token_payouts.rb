class CreateTokenPayouts < ActiveRecord::Migration
  def change
    create_table :token_payouts do |t|
      t.references :user, index: true, foreign_key: true
      t.references :issue, index: true, foreign_key: true
      t.integer :token
      t.decimal :amount, precision: 20, scale: 10
    end
    add_index :token_payouts, :user_id
    add_index :token_payouts, :issue_id
  end
end
