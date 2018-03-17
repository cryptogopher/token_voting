require_dependency 'token_votes_view_listener'
require_dependency 'token_votes_listener'
require_dependency 'issue_patch'
require_dependency 'issues_controller_patch'
require_dependency 'issues_helper_patch'
require_dependency 'settings_controller_patch'
require_dependency 'settings_helper_patch'
require_dependency 'my_controller_patch'

MyController.include MyControllerPatch

Redmine::Plugin.register :token_voting do
  name 'Token voting plugin'
  author 'cryptogopher'
  description 'Vote for Redmine issue resolution with crypto tokens'
  version '0.0.1'
  url 'https://github.com/cryptogopher/token-voting'
  author_url 'https://github.com/cryptogopher'

  menu :account_menu, :token_votes, { controller: 'my', action: 'token_votes' },
    caption: 'My token votes', first: true

  project_module :issue_tracking do
    permission :manage_token_votes, {token_votes: [:create, :destroy]}
  end

  settings default: {
    default_token: :BTCTEST,
    checkpoints: {
      '0' => { statuses: IssueStatus.all.where(is_closed: true).pluck(:id), share: 1.0 },
    },
    BTC: {
      rpc_uri: 'http://user:password@localhost:8332',
      min_conf: 6,
    },
    BCH: {
      rpc_uri: 'http://user:password@localhost:8332',
      min_conf: 6,
    },
    BTCTEST: {
      rpc_uri: 'http://user:password@localhost:18332',
      min_conf: 6,
    },
  }, partial: 'settings/token_votes'
end

