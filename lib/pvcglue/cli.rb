require 'thor'
require 'orca'
require 'pvcglue'

module Pvcglue
  class Manager < Thor # must be 'Manager' (as opposed to 'Manager_CLI') or Thor's `subcommand` gets confused using Thor <= 0.19.1

    desc "bootstrap", "bootstrap"

    def bootstrap
      Pvcglue::PvcManager.new.bootstrap
    end

    desc "push", "push"

    def push
      Pvcglue::PvcManager.new.push
    end

    desc "pull", "pull"

    def pull
      Pvcglue::PvcManager.new.pull
    end

  end

  class CLI < Thor

    desc "version", "show the version of PVC..."

    def version
      puts Pvcglue::Version.version
    end

    desc "info", "show the pvcglue version and cloud settings"

    def info
      puts "Pvcglue version #{Pvcglue::Version.version}"
      puts "  Manager settings:"
      Pvcglue.configuration.options.each { |k, v| puts "    #{k}=#{v}" }
    end

    desc "bootstrap", "bootstrap..."
    method_option :stage, :required => true, :aliases => "-s"

    def bootstrap
      puts Pvcglue::Bootstrap.run(options[:stage])
    end

    #desc "manager", "manager bootstrap|pull|push"

    desc "manager SUBCOMMAND ...ARGS", "manage manager"
    #banner 'manager'
    subcommand "manager", Manager

  end

end