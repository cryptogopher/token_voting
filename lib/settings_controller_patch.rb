module SettingsControllerPatch
  SettingsController.class_eval do
    before_filter :token_voting_settings, :only => [:plugin]

    private
    # validate settings on POST, before saving
    def token_voting_settings
      return unless request.post? && params[:id] == 'token_voting'

      begin
        TokenVote.tokens.keys.each do |token|
          uri = params[:settings][token][:rpc_uri]
          rpc = RPC::get_rpc(token, uri)
          uri = rpc.uri.to_s
          rpc.uptime

          if params[:settings][token][:min_conf] < 1
            flash[:error] = "Confirmation threshold for #{token} cannot be < 1"
          end
        end
      rescue RPC::Error, URI::Error => e
        flash[:error] = "Cannot connect to #{uri}: #{e.message}"
      end

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
