module RPC
  class BTCREG < BTC
    def initialize(*args)
      super
      @mining_address = 'mihruZNJPyFMjLm6D1tkUXrvcjuxCsoUSz'
      @mining_privkey = 'cS2dNLAw1n4NwP7F76XrivAfNN7eVwBWSgn1Ri5boxkBZEYhvsPT'
      # Key has to be imported to wallet for bitcoind to listunspent
      result = self.import_priv_key(@mining_privkey)
      raise Error, "Cannot import mining private key" if result
    end

    def generate(n)
      self.generate_to_address(n, @mining_address)
    end

    def fund(address, amount)
      amount = amount.to_d
      fee = 0.0001.to_d
      utxos = self.list_unspent(1, 9999999, [@mining_address])

      sum = 0.to_d
      selected = []
      utxos.each do |utxo|
        if utxo['spendable']
          prev_sum = sum
          prev_sum < amount+fee ? selected << utxo : break
          sum += utxo['amount']
        end
      end
      selected.each { |utxo| utxo.keep_if { |k,v| ['txid',  'vout'].include?(k) } }

      outputs = {address => amount.to_s('F'), @mining_address => (sum-amount-fee).to_s('F')}
      rtx = self.create_raw_transaction(selected, outputs)
      raise Error, "Cannot create raw transaction to #{address}" unless rtx

      stx = self.sign_raw_transaction(rtx, [], [@mining_privkey])
      result = self.send_raw_transaction(stx['hex'])
      raise Error, "Cannot send raw transaction to #{address}" unless result
      return result
    end

    def get_mined_balance
      utxos = self.list_unspent(1, 9999999, [@mining_address])
      utxos.reduce(0) { |amount, utxo| amount += utxo['amount'] if utxo['spendable'] }
    end
  end
end

