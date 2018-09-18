# token-voting

Redmine plugin: vote for Redmine issue resolution with crypto token deposits.

Issue tracker: https://tv.michalczyk.pro/ (don't be afraid, you can register/login there with your __Github account__).

## Installation

1. Check prerequisites. To use this plugin you need to have:
* Redmine (https://www.redmine.org) installed. Check that your Redmine/Rails/Ruby version is compatible with plugin. Currently supported are following versions of software:

  |        |versions |
  |--------|---------|
  |Redmine |3.4.x    |
  |Ruby    |2.3.x    |
  |Rails   |4.2.x    |

  You may try and find this plugin working on other versions too, but be prepared to get error messages. In case it works let everyone know that through issue tracker (send _support_ issue). If it doesn't work, you are welcome to send _feature_ request to make plugin compatible with other version. Keep in mind though, that for more exotic versions there will be more vote power needed to complete such feature request.

* RPC server for the token type that you are willing to use (e.g. bitcoind). Right now following tokens/versions are supported:

  |token                        |versions               |
  |-----------------------------|-----------------------|
  |BTC (bitcoind, mainnet)      |0.15.1, 0.16.0         |
  |BTCTEST (bitcoind, testnet)  |0.15.1, 0.16.0         |

  There is smaller chance that other version will work out of the box than in Redmine/RoR case. At least bitcoind RPC seems to evolve fast right now. Feature requests are welcome.
Necessary configuration will be provided later in this guide.

2. Login to shell, change to redmine user, clone plugin to your plugins directory, install gemfiles and migrate database:
   ```
   su - redmine
   git -C /var/lib/redmine/plugins/ clone https://github.com/cryptogopher/token_voting.git
   cd /var/lib/redmine
   bundle install
   RAILS_ENV=production rake redmine:plugins:migrate
   ```

3. Restart Redmine. Exact steps depend on your installation of Redmine. You may need to restart Apache (when using Passenger) or just Redmine daemon/service.

4. Update Redmine settings.
* enable REST web service (Administration -> Settings -> Enable REST web service)
* create separate Redmine user (login e.g. `rpc`) for RPC daemon to use (Administration -> Users -> New user)
* login as user `rpc`, reset API access key and copy it for next steps (My account -> API access key -> Reset, then Show)
* re-login as administrator and grant token votes permissions to roles (Administration -> Roles and permissions -> Permissions report). Token votes permissions are inside _Issue tracking_ group. There are 2 types of permissions:
  * _Add token votes_ - should be granted to everybody who need to cast votes
  * _Manage token votes_ - administrative permission granted for roles responsible for creating and signing transactions with payouts

5. Setup RPC daemon. 

6. Update plugin settings. Go to: Administration -> Plugins -> Token voting plugin -> Configure (https://your.redmine.com/settings/plugin/token_voting)
* Add at least 1 token type. Best to start with BTCTEST.
