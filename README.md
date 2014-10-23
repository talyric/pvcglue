# PVC Glue

Pico Virtual Cloud

An opinionated cloud application manager for Rails applications using your own servers.

Currently supported stack:

  * Ubuntu 12.04 (with plans for supporting 14.04)
  * Ruby >= 1.9 (multiple versions supported on same server)
  * Rails >= 3.2
  * RVM
  * Postgresql 9.1
  * Nginx
  * Passenger > 4.0
  * Memcached

# This is a work in progress

Although this project is being used on productions sites, this should be considered "Alpha" code, as things my change without notice until version 1.0.  :)

# First Time Set Up for Existing Project

Note:  An existing authorized user must perform steps 1-3.

1.  Add the new user's public key to the manager

        pvc manager user /path/to/id_rsa.pub

2.  Add the new user's public key to the project(s)

        pvc manager pull # to ensure the latest data

    Edit the file listed after "Saved as:" add public SSH key of new user to project(s)

        pvc manager push

3.  Update all environments to allow access

        pvc alpha bootstrap
        pvc beta bootstrap # if not the same set of servers as alpha
        pvc preview bootstrap # if not the same set of servers as alpha/beta
        pvc production bootstrap

4.  Configure the manager (only once per developer machine, if set as the default).

        pvc manager configure # only once per developer machine, if set as default

5.  Test.

        pvc alpha c # start a rails console on the alpha web server

6.  If you have any problems, see the [Troubleshooting](#troubleshooting) section.

## Common Usage

Always do a `pvc manager pull` once before making any changes to ensure you have the latest data.  (Caching will be improved as time permitts.)

* Deploy a stage

        pvc <stage> deploy

* Set an environment variable or variables

        pvc <stage> env set XYZ=123 [ZZZ=321] # this will restart the app

* Pull down a copy of the production db

        pvc production db pull

* Restore a db dump to you local development machine

        pvc restore path/to/dump/file.dump

* edit configuration

        pvc manager pull # to ensure the latest data

    Edit the file listed after "Saved as:"

        pvc manager push

* update deployment settings after making changes to the configuration

        pvc <stage> capify # must be done on all stages!


* restart delayed job workers (this may change once a bug is resolved)

        cap production deploy:delayed_job_restart 


# Help

    Commands:
      pvc bootstrap -s, --stage=STAGE               # bootstrap...
      pvc build -s, --stage=STAGE                   # build...
      pvc c -s, --stage=STAGE                       # shortcut for console
      pvc capify -s, --stage=STAGE                  # update capistrano configuration
      pvc console -s, --stage=STAGE                 # open rails console
      pvc db SUBCOMMAND ...ARGS                     # db utils
        pvc db config                                 # create/update database.yml
        pvc db dump                                   # dump
        pvc db help [COMMAND]                         # Describe subcommands or one specific subcommand
        pvc db info                                   # info
        pvc db pull                                   # pull
        pvc db push                                   # push
        pvc db restore                                # restore
      pvc deploy -s, --stage=STAGE                  # deploy the app
      pvc env SUBCOMMAND ...ARGS -s, --stage=STAGE  # manage stage environment
        pvc env default                               # reset env to default. Destructive!!!
        pvc env help [COMMAND]                        # Describe subcommands or one specific subcommand
        pvc env list                                  # list
        pvc env pull                                  # pull
        pvc env push                                  # push
        pvc env rm                                    # alternative to unset
        pvc env set                                   # set environment variable(s) for the stage XYZ=123 [ZZZ=321]
        pvc env unset                                 # remove environment variable(s) for the stage XYZ [ZZZ]
      pvc help [COMMAND]                            # Describe available commands or one specific c...
      pvc info                                      # show the pvcglue version and cloud settings
      pvc m -s, --stage=STAGE                       # enable or disable maintenance mode
      pvc maint -s, --stage=STAGE                   # enable or disable maintenance mode
      pvc maintenance -s, --stage=STAGE             # enable or disable maintenance mode
      pvc manager SUBCOMMAND ...ARGS                # manage manager
        pvc manager bootstrap                         # bootstrap
        pvc manager configure                         # configure
        pvc manager help [COMMAND]                    # Describe subcommands or one specific subcommand
        pvc manager info                              # show manager data
        pvc manager pull                              # pull
        pvc manager push                              # push
        pvc manager s                                 # run shell
        pvc manager shell                             # run shell
        pvc manager show                              # show manager data
      pvc s -s, --stage=STAGE                       # shell
      pvc sh -s, --stage=STAGE                      # run interactive shell on node
      pvc ssl SUBCOMMAND ...ARGS -s, --stage=STAGE  # manage ssl certificates
        pvc ssl csr                                   # create new csr
        pvc ssl help [COMMAND]                        # Describe subcommands or one specific subcommand
        pvc ssl import                                # import .key or .crt or both if no extension given (.crt must be 'pre...
      pvc version                                   # show the version of PVC...

https://github.com/radar/guides/blob/master/gem-development.md

## Installation

Add these lines to your application's Gemfile.  `dotenv-rails` must be listed first!

    ################# Must be the first Gem ###################
    gem 'dotenv-rails', "0.11.1"
    ################# Must be the first Gem ###################

Then add these lines to your application's Gemfile, whereever you like (usually at the end):

    gem 'pvcglue', "~> 0.1.9", :group => :development
    gem 'pvcglue_dbutils', "~> 0.5.3"

And then execute:

    $ bundle

## Troubleshooting

### If you see this while trying to deploy

    DEBUG[426eda1d] 	Permission denied (publickey).
    DEBUG[426eda1d] 	fatal: The remote end hung up unexpectedly

it probably means that your SSH key is not being forwarded.

You will need to edit (or create) `~/.ssh/config` and add the host(s) you want to connect to.  Replace `example.com` with the name or IP you want to connect to.  (Note:  You will need an entry for each 'web' server in the cluster in order to deploy.)

    Host example.com
      ForwardAgent yes

You can use `Host *` if you understand the security risks, and are not connecting to any untrusted servers over SSH.

And then add your key to the agent

    ssh-add -K

More information can be found at https://developer.github.com/guides/using-ssh-agent-forwarding/

### If you get an error like

    DEBUG[d416069c] 	fatal: Not a valid object name
    DEBUG[d416069c] 	tar: This does not look like a tar archive
    DEBUG[d416069c] 	tar: Exiting with failure status due to previous errors

it probably means that you have not pushed up the branch, yet.  :)

## Developing

To use locally committed gem, use

    bundle config local.pvcglue ~/projects/pvcglue

and

    bundle config --delete local.pvcglue

to restore using remote repo.  See http://ryanbigg.com/2013/08/bundler-local-paths/ and http://bundler.io/v1.3/bundle_config.html

    gem 'pvcglue', "~> 0.1.5", :github => 'talyric/pvcglue', :branch => 'master', :group => :development
    gem 'pvcglue_dbutils', "~> 0.5.2", :github => 'talyric/pvcglue_dbutils', :branch => 'master' # must be available in all environments

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

License
-------

MIT License

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
