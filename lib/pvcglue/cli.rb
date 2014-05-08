require 'thor'
require 'orca'
require 'pvcglue'

module Pvcglue

  class CLI < Thor

    def initialize(args = [], local_options = {}, config = {})
      super
      Pvcglue.cloud.set_stage(options[:stage])
      # puts "/\\"*80
      # puts options.inspect
      # puts "*"*80
    end

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

    def bootstrap(roles = 'all')
      Pvcglue::Bootstrap.run(roles)
    end

    desc "build", "build..."
    method_option :stage, :required => true, :aliases => "-s"

    def build(roles = 'all')
      Pvcglue::Nodes.build(roles)
    end

    desc "console", "open rails console"
    method_option :stage, :required => true, :aliases => "-s"

    def console(server='web')
      node = Pvcglue.cloud.find_node(server)
      node_name = node.keys.first
      node_data = node.values.first
      # puts "*"*80
      # puts node.inspect
      puts "Connection to #{node_name} (#{node_data[:public_ip]}) as user 'deploy'..."
      working_dir = Pvcglue.cloud.deploy_to_app_current_dir
      system(%(ssh -t deploy@#{node_data[:public_ip]} "cd #{working_dir} && echo 'Starting #{options[:stage].upcase} Rails console in #{working_dir}' && RAILS_ENV=#{options[:stage].downcase} script/rails c"))

    end

    desc "c", "shortcut for console"
    method_option :stage, :required => true, :aliases => "-s"

    def c(server='web')
      console(server)
    end

    desc "manager SUBCOMMAND ...ARGS", "manage manager"
    #banner 'manager'
    subcommand "manager", Manager

    desc "env SUBCOMMAND ...ARGS", "manage stage environment"
    method_option :stage, :required => true, :aliases => "-s"
    #banner 'manager'
    subcommand "env", Env

    desc "ssl SUBCOMMAND ...ARGS", "manage ssl certificates"
    method_option :stage, :required => true, :aliases => "-s"
    subcommand "ssl", Ssl


    desc "maintenance", "enable or disable maintenance mode"
    method_option :stage, :required => true, :aliases => "-s"

    def maintenance(mode)
      raise(Thor::Error, "invalid maintenance mode :(  (Hint:  try on or off.)") unless mode.in?(%w(on off))
      Pvcglue.cloud.maintenance_mode = mode
      Pvcglue::Packages.apply(:maintenance_mode, Pvcglue.cloud.nodes_in_stage('lb'))
    end

    desc "maint", "enable or disable maintenance mode"
    method_option :stage, :required => true, :aliases => "-s"

    def maint(mode)
      maintenance(mode)
    end

    desc "m", "enable or disable maintenance mode"
    method_option :stage, :required => true, :aliases => "-s"

    def m(mode)
      maintenance(mode)
    end

    desc "sh", "run interactive shell on node"
    method_option :stage, :required => true, :aliases => "-s"

    def sh(server='web') # `shell` is a Thor reserved word
      node = Pvcglue.cloud.find_node(server)
      node_name = node.keys.first
      node_data = node.values.first
      # puts "*"*80
      # puts node.inspect
      puts "Connection to #{node_name} (#{node_data[:public_ip]}) as user 'deploy'..."
      system("ssh deploy@#{node_data[:public_ip]}")
    end

    desc "shell", "shell"
    method_option :stage, :required => true, :aliases => "-s"

    def s(server='web')
      sh(server)
    end

    desc "capify", "update capistrano configuration"
    method_option :stage, :required => true, :aliases => "-s"

    def capify
      Pvcglue::Capistrano.capify
    end

    desc "deploy", "deploy the app"
    method_option :stage, :required => true, :aliases => "-s"

    def deploy
      Pvcglue::Capistrano.deploy
    end
  end

end