require_dependency 'token_voting/token_votes_view_listener'
require_dependency 'token_voting/token_votes_listener'

ActionDispatch::Reloader.to_prepare do
  Issue.include TokenVoting::IssuePatch
  IssuesController.include TokenVoting::IssuesControllerPatch
  IssuesHelper.include TokenVoting::IssuesHelperPatch

  MyController.include TokenVoting::MyControllerPatch
  MyHelper.include TokenVoting::MyHelperPatch

  SettingsController.include TokenVoting::SettingsControllerPatch
  SettingsHelper.include TokenVoting::SettingsHelperPatch

  User.include TokenVoting::UserPatch
end

Redmine::Plugin.register :token_voting do
  name 'Token voting plugin'
  author 'cryptogopher'
  description 'Vote for Redmine issue resolution with crypto tokens'
  version '0.0.1'
  url 'https://github.com/cryptogopher/token_voting'
  author_url 'https://github.com/cryptogopher'

  menu :account_menu, :token_votes, { controller: 'my', action: 'token_votes' },
    caption: 'My token votes', first: true

  project_module :issue_tracking do
    permission :add_token_votes, {
      token_votes: [:create, :destroy],
      token_withdrawals: [:create, :destroy],
    }
    permission :manage_token_votes, {
      token_withdrawals: [:payout],
    }
  end

  settings default: {
    'checkpoints' => {
      'statuses' => [
        IssueStatus.table_exists? && IssueStatus.all.where(is_closed: true).pluck(:id),
      ],
      'shares' => [1.0]
    }
  }, partial: 'settings/token_votes'
end

