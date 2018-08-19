# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

#post 'issues/:id/token_vote/create', :to => 'recurring_tasks#create'
resources :issues do
    shallow do
      resources :token_votes, :controller => 'token_votes', :only => [:create, :destroy]
    end
end
post 'token_votes/withdraw', to: 'token_votes#withdraw', as: 'withdraw_token_vote'
get 'token_votes/walletnotify/:token_type_name/:txid', to: 'token_votes#walletnotify',
  as: 'walletnotify_token_vote'
get 'token_votes/blocknotify/:token_type_name/:blockhash', to: 'token_votes#blocknotify',
  as: 'blocknotify_token_vote'

get 'my/token_votes', to: 'my#token_votes', as: 'my_token_votes'

