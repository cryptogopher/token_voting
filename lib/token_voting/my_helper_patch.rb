module TokenVoting
  module MyHelperPatch
    MyHelper.class_eval do
      def amount_precision
        precisions = TokenType.all.map { |token_t| RPC::get_rpc(token_t).class::PRECISION }
        precisions << 0
        10.to_d.power(-(precisions.max))
      end
    end
  end
end

