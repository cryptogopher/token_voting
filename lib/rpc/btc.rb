require 'net/http'
require 'uri'
require 'json'

module RPC
  class BTC
    attr_reader :uri

    PRECISION = 8

    def initialize(service_uri)
      @uri = URI.parse(URI.escape(service_uri))
      unless @uri && @uri.kind_of?(URI::HTTP) && @uri.request_uri
        raise Error, 'non HTTP/HTTPS URI provided'
      end
    end

    # Gets tuple of [[inputs], [outputs]] addresses for txid.
    def get_tx_addresses(txid)
      tx = self.decode_raw_transaction(self.get_transaction(txid, true)['hex'])

      out_addresses = []
      tx['vout'].map { |vout| out_addresses.concat(vout['scriptPubKey']['addresses']) }

      in_addresses = []
      tx['vin'].map { |vin| [vin['txid'], vin['vout']] }.each do |txid, voutn|
        begin
          in_tx = self.decode_raw_transaction(self.get_transaction(txid, true)['hex'])
          in_addresses.concat(in_tx['vout'][voutn]['scriptPubKey']['addresses'])
        rescue RPC::InvalidAddressOrKey
          # gettransaction does not provide tx details for txs not affecting wallet (if
          # -txindex is disabled). This is not a problem as we're only interested in
          # wallet transactions here: vins that are not affecting wallet can be
          # safely ignored.
        end
      end

      [in_addresses.uniq, out_addresses.uniq]
    end

    # Normalized transaction ID computation loosely based on
    # https://github.com/bitcoin/bips/blob/master/bip-0140.mediawiki
    def get_normalized_txid(raw_tx)
      raw_tx = self.decode_raw_transaction(raw_tx) if raw_tx.instance_of? String
      raw_tx.keep_if { |k,v| ['version', 'locktime', 'vin', 'vout'].include?(k) }
      raw_tx['vin'].each do |vin|
        vin['scriptSig']['asm'] = ''
        vin['scriptSig']['hex'] = ''
        vin.delete('txinwitness')
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

    def is_address_valid?(address)
      self.validate_address(address)['isvalid']
    end

    # Creates rawtransaction. inputs is a hash of hashes (amounts are BigDecimal):
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

      token_t = TokenType.find_by(name: self.class.name.demodulize)
      min_conf = token_t.min_conf

      utxos = self.list_unspent(min_conf, 9999999, flat_inputs.keys)
      selected_utxos = []
      fee_input_score = Hash.new(0)
      fee_output_score = Hash.new { |h, k| h[k] = (outputs.include?(k) ? 1 : 0)  }
      utxos.each do |utxo|
        address = utxo['address']
        if utxo['solvable'] && (flat_inputs[address] > 0)
          utxo_amount = utxo['amount'].to_d
          amount = [utxo_amount, flat_inputs[address]].min
          change = utxo_amount - amount
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
      node_version = self.get_network_info['version']
      if node_version < 16_00_00
        tx_fee_per_kb = self.estimate_fee(25)
      else
        fee_estimate = self.estimate_smart_fee(25)
        if fee_estimate.has_key?('feerate')
          tx_fee_per_kb = fee_estimate['feerate']
        else
          tx_fee_per_kb = 0.00002048.to_d
          error_msg =
            if fee_estimate.has_key?('errors') and !fee_estimate['errors'].empty?
              fee_estimate['errors'].join('. ')
            else
              'no messages'
            end
          Rails.logger.info "Smart fee estimation failed, falling back to default (%s)." %
             error_msg
        end
      end
      tx_fee = tx_fee_per_kb.to_d * tx_size / 1024.to_d
      raw_outputs = outputs.map do |address, amount|
        fee_share = (amount - fee_score[address] * tx_fee / total_fee_score).round(PRECISION)
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

      response_body = post_http_request(post_body)
      unless response_body && response_body.length > 2
        raise Error, "Empty response from RPC server" 
      end
      response = JSON.parse(response_body)
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

