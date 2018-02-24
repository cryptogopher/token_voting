module RPC
  class Error < RuntimeError
    def to_s
      "Wallet RPC call error: #{super}"
    end
  end

  module_function

  def get_rpc(token, uri = nil)
    token = token.to_sym
    rpc_class = RPC.const_get(token) rescue raise(Error, "No RPC class for: #{token}")
    rpc_class.new(uri || Setting.plugin_token_voting[token][:rpc_uri])
  end
end

