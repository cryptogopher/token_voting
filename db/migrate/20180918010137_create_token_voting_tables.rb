class CreateTokenVotingTables < ActiveRecord::Migration
  def change
    create_table :token_types do |t|
      t.string :name
      t.string :rpc_uri
      t.integer :min_conf
      t.integer :prev_sync_height
      t.boolean :is_default
    end

    create_table :token_votes do |t|
      t.references :voter, foreign: true, index: true
      t.references :issue, foreign: true, index: true
      t.references :token_type, foreign_key: true, index: true
      t.integer :duration
      t.datetime :expiration
      t.string :address
      t.decimal :amount_conf, precision: 20, scale: 10
      t.decimal :amount_unconf, precision: 20, scale: 10
      t.boolean :is_completed
    end

    create_table :token_payouts do |t|
      t.references :payee, foreign: true, index: true
      t.references :issue, foreign: true, index: true
      t.references :token_type, foreign_key: true, index: true
      t.decimal :amount, precision: 20, scale: 10
    end

    create_table :token_withdrawals do |t|
      t.references :payee, foreign: true, index: true
      t.references :token_type, foreign: true, index: true
      t.references :token_transaction, foreign: true, index: true
      t.decimal :amount, precision: 20, scale: 10
      t.string :address
      t.boolean :is_rejected
    end

    create_table :token_transactions do |t|
      t.string :ntxid
      t.text :tx
      t.boolean :is_processed
      t.timestamps null: false
    end

    create_table :token_pending_outflows do |t|
      t.references :token_vote, foreign: true, index: true
      t.references :token_transaction, foreign: true, index: true
      t.decimal :amount, precision: 20, scale: 10
    end
  end
end
