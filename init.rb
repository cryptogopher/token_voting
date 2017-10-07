require_dependency 'token_votes_hook_listener.rb'

Redmine::Plugin.register :token_voting do
  name 'Token voting plugin'
  author 'Piotr Michalczyk'
  description 'Vote for Redmine ticket resolution with crypto tokens'
  version '0.0.1'
  url 'https://github.com/cryptogopher/token-voting'
  author_url 'https://github.com/cryptogopher'
end
