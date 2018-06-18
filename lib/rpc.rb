module RPC
  class Error < RuntimeError
    def to_s
      "Wallet RPC call error: #{super}"
    end
  end

  module_function

  def get_rpc(tt_name, uri = nil)
    begin
      rpc_class = RPC.const_get(tt_name.to_sym) 
    rescue
      raise(Error, "No RPC class for: #{tt_name}")
    end
    rpc_class.new(uri || TokenType.find_by_name(tt_name).rpc_uri)
  end
end

