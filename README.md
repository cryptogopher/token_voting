# token-voting

Redmine plugin: vote for Redmine issue resolution with crypto token deposits.

## Installation

0. To use this plugin you need to have Redmine (https://www.redmine.org) installed.

1. Check that your Redmine/Rails/Ruby version is compatible with plugin. Currently supported are following versions of software:
* Redmine version                3.4.5
* Ruby version                   2.3.6
* Rails version                  4.2.10

2. Change to redmine user, clone plugin to your plugins directory and install gemfiles:
   ```
   su - redmine
   git -C /var/lib/redmine/plugins/ clone https://github.com/cryptogopher/token_voting.git
   cd /var/lib/redmine
   bundle install
   ```

3. Restart Redmine. Exact steps depend on your installation of Redmine. You may need to restart Apache (when using Passenger) or just Redmine daemon/service.

4. Setup plugin settings. Go to https://your.redmine.com/settings/plugin/token_voting (or Redmine -> Administration -> Plugins -> Token voting plugin -> Configure)

5. Enable _Manage token votes_ permissions (https://your.redmine.com/roles/permissions)
   - it is under _Issue tracking_
