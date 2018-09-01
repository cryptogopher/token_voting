class AddPrecisionToTokenTypes < ActiveRecord::Migration
  def change
    add_column :token_types, :precision, :integer
  end
end
