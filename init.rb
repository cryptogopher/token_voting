require_dependency 'bitcoin_votes_hook_listener.rb'

Redmine::Plugin.register :bitcoin_voting do
  name 'Bitcoin Voting plugin'
  author 'Piotr Michalczyk'
  description 'Vote for Redmine ticket resolution with Bitcoin'
  version '0.0.1'
  url 'https://github.com/cryptogopher/bitcoin_voting'
  author_url 'https://github.com/cryptogopher'
end
