module SettingsControllerPatch
  SettingsController.class_eval do
    before_filter :token_voting_settings, :only => [:plugin]

    private
    def token_voting_settings
      @plugin = Redmine::Plugin.find(params[:id])
      return unless @plugin.name == 'token_voting'

      if request.post?
        # validate settings before sending
      else
        # set defaults if not configured
        if Setting.plugin_token_voting.empty?
          Setting.plugin_token_voting = @plugin.settings[:default]
        end
      end
    end
  end
end

SettingsController.include SettingsControllerPatch
