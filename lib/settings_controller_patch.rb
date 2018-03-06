module SettingsControllerPatch
  SettingsController.class_eval do
    before_filter :token_voting_settings, :only => [:plugin]

    private
    # validate settings on POST, before saving
    def token_voting_settings
      return unless request.post? && params[:id] == 'token_voting'

      errors = []

      # Checkpoints checks
      sum = 0.0
      params[:settings][:checkpoints].each do |number, values|
        if values[:statuses].nil? || values[:statuses].empty?
          errors << "Checkpoint #{number} has to have at least 1 status selected"
        end
        sum += values[:share].to_f
      end
      errors << "Sum of checkpoint shares has to equal 1.00" unless sum == 1.0
      
      # RPC checks
      TokenVote.tokens.keys.each do |token|
        begin
          uri = params[:settings][token][:rpc_uri]
          rpc = RPC::get_rpc(token, uri)
          uri = rpc.uri.to_s
          rpc.uptime

          if params[:settings][token][:min_conf].to_i < 1
            errors << "Confirmation threshold for #{token} has to be 1 or more"
          end
        rescue RPC::Error, URI::Error => e
          errors << "Cannot connect to #{token} RPC #{uri}: #{e.message}"
        end
      end

      if errors.present?
        flash[:error] = errors.join('<br>').html_safe
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
