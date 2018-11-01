# token_voting

Redmine plugin: vote for Redmine issue resolution with crypto token deposits.

Issue tracker: https://it.michalczyk.pro/ (don't be afraid, you can register/login there with your __Github account__).

Screenshots: https://it.michalczyk.pro/projects/token-voting/wiki/Screenshots

## Motivation

In a world where increasingly more of what is possible and impossible is defined by a software we use (and yes, you can treat _cost prohibitive_ as _impossible_ as well), we need a software that will solve our problems; instead of being limited to solving problems that the software at hand can solve.

To drive the software creation towards fulfilling our needs, there has to be environment of engineers and users coupled by a feedback loop. One that will incentivise both sides to produce desired products. Best if this environment could build software on a _cost per effort_ basis instead of anachronistic and ineffective _cost per user/usage period/license_ models.

This Redmine plugin is an attempt to provide tool necessary to create and maintain such environment.

### Advantages

Proposed solution has following advantages:
* **avoids placing the cost of creating feature/fixing bug on single entity**. Many times cost (in terms of money, but also time required to go through the process) for the single entity can significantly exceed potential profits. Thus it may be economically unjustified. This solution **allows to distribute cost between many interested entities**. Some of the most wanted features have tens of proponents. Just 10 of enities willing to support particular feature/bugfix make entry barrier one order of magnitute smaller.
* avoids situation where particular **needs of single entities that could finance development of some features may not overlap with the needs of wide community**. There is significant risk, that code built exclusively by them will not be accepted by project developers. That in turn will encourage entities to keep their code for themselves or make it available as a hard to maintain patches.
* besides providing financial incentive, **voting with tokens will provide information regarding popularity** of particular feature/bug. This way developers can both optimize for most frequently wanted features/bugfixes and avoid implementing those least requested. 
* **freedom of choice of what to implement and what not is retained** in the hands of developers. All votes on unimplemented features go back to voter sooner or later.
* most of the development **work can be done by competent people**, already knowing project internals best.
* last but not least it introduces some **gamification** elements into development process. Writing code may not only be rewarding, but also fun.

## Purpose

Of course there can be more than one way of taking advantage of such voting system, than efficiently producing free and open source software. You can find it valuable wherever you want to allow the public to manage some limited resource on a _most demanded - first served_ basis. Don't let anyone hold back your imagination! And let me know what _token voting_ enabled you to achieve!

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
   * enable REST web service (Administration -> Settings -> API -> Enable REST web service)
   * create separate Redmine user (login e.g. `rpc`) for RPC daemon to use (Administration -> Users -> New user)
   * login as user `rpc`, reset API access key and copy it for next steps (My account -> API access key -> Reset, then Show)
   * re-login as administrator and grant token votes permissions to roles (Administration -> Roles and permissions -> Permissions report). Token votes permissions are inside _Issue tracking_ group. There are 2 types of permissions:
     * _Add token votes_ - should be granted to everybody who needs to cast votes
     * _Manage token votes_ - administrative permission granted for roles responsible for creating and signing transactions containing payouts

5. Setup RPC daemon. This step depends on token type that you want to use.
   * BTCTEST is a great choice for start
     * install _bitcoind_ if not already installed
     * copy _bitcoin.conf_ from plugin directory: _token_voting/lib/configs/BTCTEST/bitcoin.conf_ to location supported by your _bitcoind_
     * fill fields marked by _<>_ inside copied configuration file with information specific to your installation
     * restart _bitcoind_

   Information regarding BTC will be provided after plugin will receive some testing from users. Specifically when using mainnet it is of crucial importance to __never leave private key on RPC daemon (use watch-only wallet)__. All transaction signing must take place outside of plugin and is not supported by design to discourage creating easy to steal hot wallets.

6. Update plugin settings. (Administration -> Plugins -> Token voting plugin -> Configure)
   * Add at least 1 token type (New token type). Best to start with BTCTEST. RPC URI should match RPC daemon set up in previous steps.
   * Configure checkpoints. For start you can leave 1 checkpoint with statuses corresponding to succesfully closed issue and share equal 1.

7. Go to Redmine, create/open issue, add token vote and transfer some funds to it. Refresh view and observe if unconfirmed amount changed from 0. If yes - you're done. Otherwise:
   * double check if installation steps were executed properly
   * refer to Troubleshooting section to look for known problems
   * if nothing else helps - open _support_ issue on issue tracker (link at the top).

8. Have fun!

## Troubleshooting

_Yet to come._

## Contributing

_Yet to come._

