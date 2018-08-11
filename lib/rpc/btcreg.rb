module RPC
  class BTCREG < BTC
    #def initialize(*args)
    #  super
    #  @mining_address = 'mihruZNJPyFMjLm6D1tkUXrvcjuxCsoUSz'
    #  @mining_privkey = 'cS2dNLAw1n4NwP7F76XrivAfNN7eVwBWSgn1Ri5boxkBZEYhvsPT'
    #  # Key has to be imported to wallet for bitcoind to listunspent
    #  result = self.import_priv_key(@mining_privkey)
    #  raise Error, "Cannot import mining private key" if result
    #end

    ## Make 'generate' synchronous so assert_notifications won't timeout due to
    ## block generation time unpredictability.
    #def generate(n)
    #  prev_block_count = self.get_block_count
    #  super
    #  Timeout.timeout(60) do
    #    sleep 0.2 while self.get_block_count < prev_block_count+n
    #  end
    #end

    def send_from_address(from_address, to_address, amount, fee_included=true)
      fee = 0.001.to_d
      amount = fee_included ? amount.to_d-fee : amount.to_d
      total = amount+fee

      utxos = self.list_unspent(1, 9999999, [from_address])

      sum = 0.to_d
      selected_utxos = []
      utxos.each do |utxo|
        if utxo['spendable']
          prev_sum = sum
          prev_sum < total ? selected_utxos << utxo : break
          sum += utxo['amount']
        end
      end
      raise Error "Insufficient confirmed funds on #{from_address}" if sum < total

      selected_utxos.each { |utxo| utxo.keep_if { |k,v| ['txid',  'vout'].include?(k) } }
      outputs = {to_address => amount.to_s('F'), from_address => (sum-total).to_s('F')}
      rtx = self.create_raw_transaction(selected_utxos, outputs)
      raise Error, "Cannot create raw transaction to #{address}" unless rtx

      stx = self.sign_raw_transaction(rtx)
      result = self.send_raw_transaction(stx['hex'])
      raise Error, "Cannot send raw transaction to #{address}" unless result
      return result
    end

    #def get_mined_balance
    #  utxos = self.list_unspent(1, 9999999, [@mining_address])
    #  utxos.reduce(0) { |amount, utxo| amount += utxo['amount'] if utxo['spendable'] }
    #end
  end
end

