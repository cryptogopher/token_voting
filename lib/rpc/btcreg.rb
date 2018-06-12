module RPC
  class BTCREG < BTC
    def initialize(*args)
      super
      #@mining_address = 'mxRq2LwTeXQqDhU3Q9tdVHdSZjs5nT8n17'
      #@mining_privkey = 'cQ9c5U6851yRzTZwTKbFzV225KQwEerUiAWzzLfxpMA9RjXk3dvN'
      @mining_address = 'mihruZNJPyFMjLm6D1tkUXrvcjuxCsoUSz'
      @mining_privkey = 'cS2dNLAw1n4NwP7F76XrivAfNN7eVwBWSgn1Ri5boxkBZEYhvsPT'
      result = self.import_priv_key(@mining_privkey)
      raise Error, "Cannot import mining private key" if result
    end

    def generate(n)
      self.generate_to_address(n, @mining_address)
    end

    def fund(address, amount)
      byebug
      utxos = self.list_unspent(1, 9999999, [@mining_address])
      utxos.each { |utxo| utxo.keep_if { |k,v| ['txid',  'vout'].include?(k) } }
      rtx = self.create_raw_transaction(utxos, {address => amount})
      raise Error, "Cannot create raw transaction to #{address}" unless rtx
      stx = self.fund_raw_transaction(rtx, {'changeAddress' => @mining_address})
      sstx = self.sign_raw_transaction(stx['hex'], [], [@mining_privkey])
      result = self.send_raw_transaction(sstx['hex'])
      raise Error, "Cannot send raw transaction to #{address}" unless result
    end
  end
end

