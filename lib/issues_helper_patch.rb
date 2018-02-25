require 'rqrcode'

module IssuesHelperPatch
  IssuesHelper.class_eval do
    # https://dopiaza.org/tools/datauri/index.php
    def qrcode_data_uri(address)
      qrcode = RQRCode::QRCode.new(address)
      png = qrcode.as_png(size: 256, border_modules: 2)
      png.to_data_url
    end
  end
end

IssuesHelper.include IssuesHelperPatch

