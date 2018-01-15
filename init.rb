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
    BTC: {
      master_pk: 'xyz',
      confirmations: 6,
    },
    BCH: {
      master_pk: 'abc',
      confirmations: 2,
    },
  }, partial: 'token_votes/settings'
end
