class CreateTokenTypes < ActiveRecord::Migration
  def change
    create_table :token_types do |t|
      t.string :name
      t.string :rpc_uri
      t.integer :min_conf
      t.integer :last_synced_block
      t.boolean :default
    end
  end
end
