class ChangeAmountToAmountConf < ActiveRecord::Migration
  def change
    rename_column :token_votes, :amount, :amount_conf
  end
end
