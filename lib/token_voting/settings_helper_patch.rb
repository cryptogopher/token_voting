module TokenVoting
  module SettingsHelperPatch
    SettingsHelper.class_eval do
      def options_for_checkpoint_statuses(defaults)
        options_from_collection_for_select(IssueStatus.all, :id, :name, defaults)
      end
    end
  end
end

