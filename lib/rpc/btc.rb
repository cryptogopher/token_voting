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

    # https://bitcoin.org/en/developer-reference#rpc-quick-reference
    def method_missing(name, *args)
      post_body = { method: name, params: args, id: 'token_voting', jsonrpc: '1.0' }.to_json
      response = JSON.parse(post_http_request(post_body))
      if response['error']
        raise Error, response['error']
      end
      response['result']
    end

    def post_http_request(post_body)
      http = Net::HTTP.new(@uri.host, @uri.port)
      http.open_timeout = 10
      http.read_timeout = 10
      request = Net::HTTP::Post.new(@uri.request_uri)
      request.basic_auth @uri.user, @uri.password
      request.content_type = 'application/json'
      request.body = post_body
      begin
        response = http.request(request)
      rescue StandardError => e
        raise Error, e.message
      end
      unless response.kind_of? Net::HTTPSuccess
        raise Error, response.message
      end
      response.body
    end
  end
end

