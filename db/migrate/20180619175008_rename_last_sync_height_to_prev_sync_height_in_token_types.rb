class RenameLastSyncHeightToPrevSyncHeightInTokenTypes < ActiveRecord::Migration
  def change
    rename_column :token_types, :last_sync_height, :prev_sync_height
  end
end
