class ChangePayoutsTokenToTokenType < ActiveRecord::Migration
  def change
    remove_column :token_payouts, :token
    add_reference :token_payouts, :token_type, foreign_key: true, index: true
  end
end
