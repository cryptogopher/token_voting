module RPC
  class BTCREG < BTC
    def initialize(*args)
      super
      @@mining_address ||= self.get_new_address
    end

    def generate(n)
      self.generate_to_address(n, @@mining_address)
    end
  end
end

