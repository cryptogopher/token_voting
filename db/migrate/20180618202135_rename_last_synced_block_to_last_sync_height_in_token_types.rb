class RenameLastSyncedBlockToLastSyncHeightInTokenTypes < ActiveRecord::Migration
  def change
    rename_column :token_types, :last_synced_block, :last_sync_height
  end
end
