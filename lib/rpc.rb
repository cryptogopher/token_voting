module RPC
  class Error < RuntimeError
    def to_s
      "Wallet RPC call error: #{super}"
    end
  end

  module_function

  def get_rpc(token_type, uri = nil)
    begin
      rpc_class = RPC.const_get(token_type.name.to_sym) 
    rescue
      raise(Error, "No RPC class for: #{token_type.name.to_sym}")
    end
    rpc_class.new(uri || token_type.rpc_uri)
  end
end

