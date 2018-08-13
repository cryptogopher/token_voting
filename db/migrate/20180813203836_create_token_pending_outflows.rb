class CreateTokenPendingOutflows < ActiveRecord::Migration
  def change
    create_table :token_pending_outflows do |t|
      t.references :token_vote, foreign: true, index: true
      t.references :token_transaction, foreign: true, index: true
      t.decimal :amount, precision: 20, scale: 10
    end
  end
end
