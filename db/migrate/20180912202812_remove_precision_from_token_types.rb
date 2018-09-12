class RemovePrecisionFromTokenTypes < ActiveRecord::Migration
  def change
    remove_column :token_types, :precision
  end
end
