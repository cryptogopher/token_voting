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

    # getmempoolentry which does not throw exception if txid is not in mempool.
    def get_mempool_entry(txid)
      self.getmempoolentry(txid)
    rescue RPC::InvalidAddressOrKey
      {}
    end

    # Creates rawtransaction. Parameters are arrays containing:
    # [[address1, amount1], [address2, amount2], ...]
    def create_raw_tx(inputs, outputs)
      ["txid", "tx"]
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

