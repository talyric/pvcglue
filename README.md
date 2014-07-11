# Pvcglue

    Commands:
      pvc bootstrap -s, --stage=STAGE               # bootstrap...
      pvc build -s, --stage=STAGE                   # build...
      pvc c -s, --stage=STAGE                       # shortcut for console
      pvc capify -s, --stage=STAGE                  # update capistrano configuration
      pvc console -s, --stage=STAGE                 # open rails console
      pvc db SUBCOMMAND ...ARGS                     # db utils
      pvc deploy -s, --stage=STAGE                  # deploy the app
      pvc env SUBCOMMAND ...ARGS -s, --stage=STAGE  # manage stage environment
      pvc help [COMMAND]                            # Describe available commands or one specific c...
      pvc info                                      # show the pvcglue version and cloud settings
      pvc m -s, --stage=STAGE                       # enable or disable maintenance mode
      pvc maint -s, --stage=STAGE                   # enable or disable maintenance mode
      pvc maintenance -s, --stage=STAGE             # enable or disable maintenance mode
      pvc manager SUBCOMMAND ...ARGS                # manage manager
      pvc s -s, --stage=STAGE                       # shell
      pvc sh -s, --stage=STAGE                      # run interactive shell on node
      pvc ssl SUBCOMMAND ...ARGS -s, --stage=STAGE  # manage ssl certificates
      pvc version                                   # show the version of PVC...

https://github.com/radar/guides/blob/master/gem-development.md

## Installation

Add this line to your application's Gemfile:

    group :development do
      gem 'pvcglue', "~> 0.1.0", :github => 'talyric/pvcglue', :branch => 'master', :require => false

      # This should be used once gem is 'official' :)
      #gem 'pvcglue'
    end

    gem 'pvcglue_dbutils', "~> 0.5.1", :github => 'talyric/pvcglue_dbutils', :branch => 'master' # must be available in all environments

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install pvcglue

## Usage

TODO: Write usage instructions here

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
