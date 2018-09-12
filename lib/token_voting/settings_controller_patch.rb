module TokenVoting
  module SettingsControllerPatch
    SettingsController.class_eval do
      before_filter :token_voting_settings, :only => [:plugin]

      private

      def token_voting_settings
        return unless params[:id] == 'token_voting'
        if request.post?
          post_token_voting_settings
        elsif request.get?
          get_token_voting_settings
        end
      end

      def get_token_voting_settings
        @settings = params[:settings]
        @token_types = TokenType.all
      end

      # validate settings on POST, before saving
      def post_token_voting_settings
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
          elsif value.to_d < 0.01 || value.to_d > 1.0
            errors << "Checkpoint #{index+1} has share outside defined range 0.01 - 1.0"
          end
        end

        if shares.reduce(0) { |sum, a| sum += a.to_d } != 1.0
          errors << "Sum of checkpoint shares has to equal 1.0"
        end

        if errors.present?
          flash[:error] = errors.join('<br>').html_safe
          #render_token_voting_settings(params)
        end
      end
    end
  end
end

