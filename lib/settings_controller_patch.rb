module SettingsControllerPatch
  SettingsController.class_eval do
    before_filter :token_voting_settings, :only => [:plugin]

    private
    # validate settings on POST, before saving
    def token_voting_settings
      return unless request.post? && params[:id] == 'token_voting'

      begin
        uri = params[:settings][:btc_rpc_uri]
        rpc = RPC::Bitcoin.new(uri)
        uri = rpc.uri.to_s
        rpc.uptime

        uri = params[:settings][:bch_rpc_uri]
        rpc = RPC::Bitcoin.new(uri)
        uri = rpc.uri.to_s
        rpc.uptime
      rescue RPC::Error, URI::Error => e
        flash[:error] = "Cannot connect to #{uri}: #{e.message}"
      end

      if params[:settings][:btc_confirmations] < 1:
        flash[:error] = "Confirmation threshold for BTC cannot be < 1"
      if params[:settings][:bch_confirmations] < 1:
        flash[:error] = "Confirmation threshold for BCH cannot be < 1"

      if flash[:error]
        @plugin = Redmine::Plugin.find(params[:id])
        @settings = params[:settings]
        @partial = @plugin.settings[:partial]
        render
      end
    rescue Redmine::PluginNotFound
      render_404
    end
  end
end

SettingsController.include SettingsControllerPatch
