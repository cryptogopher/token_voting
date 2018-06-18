class ChangeTokenToTokenType < ActiveRecord::Migration
  def change
    remove_column :token_votes, :token
    add_reference :token_votes, :token_type, foreign_key: true, index: true
  end
end
