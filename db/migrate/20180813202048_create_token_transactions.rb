class CreateTokenTransactions < ActiveRecord::Migration
  def change
    create_table :token_transactions do |t|
      t.string :txid
      t.string :tx
      t.boolean :is_processed
    end
  end
end
