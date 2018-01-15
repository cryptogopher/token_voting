= token-voting

Redmine plugin for voting on issues by making crypto token deposits.

Developing for:
  Redmine version                3.2.1.stable
  Ruby version                   2.1.7-p400
  Rails version                  4.2.7.1

== Installation

To use this plugin you need to have Redmine (https://www.redmine.org) installed. If you don't - it is of no use.

Check that your Redmine version is compatible with plugin. Currently supported versions of Redmine:
- 3.2

Copy plugin to your plugin directory:
  cd /your/redmine/directory/plugins/
  git clone https://github.com/cryptogopher/token_voting

Restart Redmine. Exact steps depend on your installation of Redmine. You may need to restart Apache (if using Passenger) or just Redmine daemon.

Setup plugin settings (https://your.redmine.com/settings/plugin/token_voting)

Enable "Manage token votes" permissions (https://your.redmine.com/roles/permissions)
- it is under "Issue tracking"
