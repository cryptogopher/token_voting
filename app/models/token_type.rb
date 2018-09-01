class TokenType < ActiveRecord::Base
  validates :name, :rpc_uri, presence: true
  validates :min_conf, numericality: { greater_than_or_equal_to: 0 }
  validates :prev_sync_height, numericality: { greater_than_or_equal_to: 0 }
  validates :precision, numericality: { greater_than_or_equal_to: 0 }
  validates :default, inclusion: [true, false]
end

