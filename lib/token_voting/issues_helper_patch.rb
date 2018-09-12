require 'rqrcode'

module TokenVoting
  module IssuesHelperPatch
    IssuesHelper.class_eval do
      # https://dopiaza.org/tools/datauri/index.php
      def qrcode_data_uri(address)
        qrcode = RQRCode::QRCode.new(address)
        png = qrcode.as_png(size: 256, border_modules: 2)
        png.to_data_url
      end

      TOKEN_UNITS = {
        unit: '', thousand: 'k', million: 'M', billion: 'G',
        mili: 'm', micro: 'u', nano: 'n'
      }
      # Display amount in human readable format
      def humanify_amount(amount)
        number_to_human(amount, units: TOKEN_UNITS)
      end

      def token_vote_token_options
        TokenType.all.pluck(:name, :id)
      end

      def token_vote_duration_options
        TokenVote::DURATIONS
      end
    end
  end
end

