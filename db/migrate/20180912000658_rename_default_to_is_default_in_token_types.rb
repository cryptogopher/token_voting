class RenameDefaultToIsDefaultInTokenTypes < ActiveRecord::Migration
  def change
    rename_column :token_types, :default, :is_default
  end
end
