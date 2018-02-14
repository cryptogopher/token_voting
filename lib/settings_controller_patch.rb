module SettingsControllerPatch
  SettingsController.class_eval do
    before_filter :token_voting_settings, :only => [:plugin]

    private
    def token_voting_settings
      # validate settings on POST, before saving
      return unless request.post? && params[:id] == 'token_voting'

      begin
        uri = params[:settings][:btc_rpc_url]
        rpc = RPC::Bitcoin.new(uri)
        uri = rpc.uri.to_s
        rpc.uptime

        uri = params[:settings][:bch_rpc_url]
        rpc = RPC::Bitcoin.new(uri)
        uri = rpc.uri.to_s
        rpc.uptime
      rescue RPC::Error, URI::Error => e
        flash[:error] = "Cannot connect to #{uri}: #{e.message}"

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
