require_dependency 'token_votes_hook_listener'
require_dependency 'issue_patch'
require_dependency 'issues_controller_patch'
require_dependency 'issues_helper_patch'

Redmine::Plugin.register :token_voting do
  name 'Token voting plugin'
  author 'cryptogopher'
  description 'Vote for Redmine issue resolution with crypto tokens'
  version '0.0.1'
  url 'https://github.com/cryptogopher/token-voting'
  author_url 'https://github.com/cryptogopher'

  project_module :issue_tracking do
    permission :manage_token_votes, {token_votes: [:create, :destroy]}
  end

  settings default: {
    btc_rpc_url: 'http://localhost/rpc',
    btc_confirmations: 6,
    bch_rpc_url: 'http://localhost/rpc',
    bch_confirmations: 6,
  }, partial: 'token_votes/settings'
end
