require 'thor'
require 'pvcglue'

module Pvcglue
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
      puts Pvcglue::Bootstrap.bootstrap(options[:stage])
    end

  end
end