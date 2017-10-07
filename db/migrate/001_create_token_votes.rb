class CreateTokenVotes < ActiveRecord::Migration
  def change
    create_table :token_votes do |t|
      t.references :issue, index: true, null: false
      t.references :user, index: true
      t.datetime :expiration
    end
  end
end
