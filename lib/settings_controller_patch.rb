module SettingsControllerPatch
  SettingsController.class_eval do
    before_filter :token_voting_settings, :only => [:plugin]

    private

    def render_token_voting_settings(params)
      @plugin = Redmine::Plugin.find(params[:id])
      @settings = params[:settings]
      @partial = @plugin.settings[:partial]
      render
    end

    # validate settings on POST, before saving
    def token_voting_settings
      return unless request.post? && params[:id] == 'token_voting'

      # Statuses from each multiple-select have appended '' from hidden input
      unsplit = params[:settings][:checkpoints][:statuses][0...-1]
      params[:settings][:checkpoints][:statuses] = unsplit.split('')

      # Process settings checks
      errors = []

      # - checkpoints checks
      statuses = params[:settings][:checkpoints][:statuses]
      shares = params[:settings][:checkpoints][:shares]

      if statuses.size != shares.size
        errors << "Checkpoint data invalid: different # of statuses and shares"
      end

      statuses.each_with_index do |values, index|
        if values.nil? || values.empty?
          errors << "Checkpoint #{index+1} has to have at least 1 status selected"
        end
      end
      
      shares.each_with_index do |value, index|
        if value.nil? || value.empty?
          errors << "Checkpoint #{index+1} share is not set"
        elsif value.to_f < 0.01 || value.to_f > 1.0
          errors << "Checkpoint #{index+1} has share outside defined range 0.01 - 1.0"
        end
      end

      if shares.reduce(0) { |sum, a| sum += a.to_f } != 1.0
        errors << "Sum of checkpoint shares has to equal 1.0"
      end

      # - RPC checks
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
        render_token_voting_settings(params)
      end
    rescue Redmine::PluginNotFound
      render_404
    end
  end
end

SettingsController.include SettingsControllerPatch

