module TokenVoting
  module MyHelperPatch
    MyHelper.class_eval do
      def amount_precision
        precisions = TokenType.all.map { |token_t| RPC::get_rpc(token_t).class::PRECISION }
        precisions << 0
        10.to_d.power(-(precisions.max))
      end

      def decode_tx(transaction)
        token_t = transaction.token_withdrawals.first.token_type
        rpc = RPC::get_rpc(token_t)
        JSON.pretty_generate(rpc.decode_raw_transaction(transaction.tx))
      end
    end
  end
end

