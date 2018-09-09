require 'net/http'
require 'uri'
require 'json'

module RPC
  class BTC
    attr_reader :uri

    def initialize(service_uri)
      @uri = URI.parse(URI.escape(service_uri))
      unless @uri && @uri.kind_of?(URI::HTTP) && @uri.request_uri
        raise Error, 'non HTTP/HTTPS URI provided'
      end
    end

    # Gets tuple of [[inputs], [outputs]] addresses for txid.
    def get_tx_addresses(txid)
      tx = self.get_raw_transaction(txid, true)
      input_vouts = []
      tx['vin'].each do |vin|
        begin
          input_vouts << self.get_raw_transaction(vin['txid'], true)['vout'][vin['vout']]
        rescue RPC::InvalidAddressOrKey
          # getrawtransaction does not provide rawtx for txs not affecting wallet if
          # txindex is disabled. This is not a problem as we're only interested in
          # wallet transactions here.
        end
      end
      [input_vouts, tx['vout']].map do |vouts|
        vouts.map! do |vout|
          vout['scriptPubKey']['addresses']
        end
        vouts.flatten
      end
    end

    # Normalized transaction ID computation loosely based on
    # https://github.com/bitcoin/bips/blob/master/bip-0140.mediawiki
    def get_normalized_txid(raw_tx)
      raw_tx = self.decode_raw_transaction(raw_tx) if raw_tx.instance_of? String
      raw_tx.keep_if { |k,v| ['version', 'locktime', 'vin', 'vout'].include?(k) }
      raw_tx['vin'].each do |vin|
        vin['scriptSig']['asm'] = ''
        vin['scriptSig']['hex'] = ''
      end
      first_digest = Digest::SHA256.digest(raw_tx.to_json)
      Digest::SHA256.hexdigest(first_digest)
    end

    # getmempoolentry which does not throw exception if txid is not in mempool.
    def get_mempool_entry(txid)
      self.getmempoolentry(txid)
    rescue RPC::InvalidAddressOrKey
      {}
    end

    # Creates rawtransaction. inputs is a hash of hashes:
    # {output_addr1: {input_addr1: amount1, input_addr2: amount2}, output_addr2: {...}, ...}
    # (list of input amounts per output is necessary fo fair fee calculation)
    # outputs is a hash:
    # {output_addr1: output_amount1, output_addr2: output_amount2, ...}
    # change goes to inputs.
    def create_raw_tx(inputs, outputs)
      flat_inputs = inputs.values.reduce { |memo, v| memo.merge!(v) { |k, vm, vn| vm+vn } }

      common_addresses = flat_inputs.keys.to_set & outputs.keys.to_set
      common_addresses.each do |address|
        min_amount = min([flat_inputs[address], outputs[address]])
        flat_inputs[address] -= min_amount
        flat_inputs.delete(address) if flat_inputs[address] == 0
        outputs[address] -= min_amount
        outputs.delete(address) if outputs[address] == 0
      end

      # FIXME: fee computing
      #inputs.default = 0.to_d
      #outputs.default = 0.to_d
      token_t = TokenType.find_by(name: self.class.name.demodulize)
      min_conf = token_t.min_conf
      precision = token_t.precision

      utxos = self.list_unspent(min_conf, 9999999, flat_inputs.keys)
      selected_utxos = []
      fee_input_score = Hash.new(0)
      fee_output_score = Hash.new { |h, k| h[k] = (outputs.include?(k) ? 1 : 0)  }
      utxos.each do |utxo|
        address = utxo['address']
        if utxo['solvable'] && (flat_inputs[address] > 0)
          amount = [utxo['amount'], flat_inputs[address]].min
          change = utxo['amount'] - amount
          flat_inputs[address] -= amount
          if change > 0
            fee_output_score[address] += 1 if outputs[address] == 0
            outputs[address] += change
          end
          fee_input_score[address] += 1
          selected_utxos << utxo
        end
      end

      if flat_inputs.values.sum > 0
        raise Error "Insufficient confirmed funds on inputs #{flat_inputs}"
      end

      fee_score = Hash.new(0.to_d)
      inputs.map do |address, amounts|
         fee_score[address] = fee_output_score[address] + amounts.reduce(0) do |memo, (k,v)|
           memo + (flat_inputs[k] > 0 ? fee_input_score[k] * v / flat_inputs[k] : 0)
         end
      end
      total_fee_score = fee_score.values.sum

      # Estimate tx size
      # TODO: check if 'size' is proper measure for witness transactions
      selected_utxos.each { |utxo| utxo.keep_if { |k,v| ['txid',  'vout'].include?(k) } }
      raw_outputs = outputs.map { |address, amount| [address, amount.to_s('F')] }
      rtx_est = self.create_raw_transaction(selected_utxos, raw_outputs.to_h)
      raise Error, "Cannot create raw transaction to #{outputs}" unless rtx_est
      tx_size = self.decode_raw_transaction(rtx_est)['size']

      # Create correct tx
      tx_fee = self.estimate_fee(25).to_d * tx_size / 1024
      raw_outputs = outputs.map do |address, amount|
        fee_share = (amount - fee_score[address] * tx_fee / total_fee_score).round(precision)
        [address, fee_share.to_s('F')]
      end
      rtx = self.create_raw_transaction(selected_utxos, raw_outputs.to_h)
      raise Error, "Cannot create raw transaction to #{outputs}" unless rtx

      [self.get_normalized_txid(rtx), rtx]
    end

    protected

    # https://bitcoin.org/en/developer-reference#rpc-quick-reference
    def method_missing(name, *args)
      post_body = {
        method: name.to_s.delete('_'),
        params: args,
        id: 'token_voting',
        jsonrpc: '1.0'
      }.to_json

      response = JSON.parse(post_http_request(post_body))
      if response['error']
        case response['error']['code']
        when -5
          raise InvalidAddressOrKey, response['error']['message']
        else
          raise Error, "#{response['error']['code']} #{response['error']['message']}"
        end
      end
      response['result']
    end

    def post_http_request(post_body)
      http = Net::HTTP.new(@uri.host, @uri.port)
      http.open_timeout = 10
      http.read_timeout = 10
      request = Net::HTTP::Post.new(@uri.request_uri)
      request.basic_auth(@uri.user, @uri.password)
      request.content_type = 'application/json'
      request.body = post_body
      begin
        response = http.request(request)
      rescue StandardError => e
        raise Error, e.message
      end
      unless response.class.body_permitted?
        raise Error, "#{response.code} #{response.message}"
      end
      response.body
    end
  end
end

