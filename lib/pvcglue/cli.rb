require 'thor'
require 'orca'
require 'pvcglue'

module Pvcglue

  class CLI < Thor
    class_option :cloud_manager_override

    def initialize(args = [], local_options = {}, config = {})
      super
      Pvcglue.cloud.set_stage(options[:stage])
      Pvcglue.command_line_options = options
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
      puts "Options:  #{options}"
      puts "  Manager settings:"
      Pvcglue.configuration.options.each { |k, v| puts "    #{k}=#{v}" }
    end

    desc "show", "show the pvcglue version and cloud settings"

    def show
      info
    end

    desc "bootstrap", "bootstrap..."
    method_option :stage, :required => true, :aliases => "-s"

    def bootstrap(roles = 'all')
      Pvcglue::Bootstrap.run(roles)
    end

    desc "build", "build...zzz"
    method_option :stage, :required => true, :aliases => "-s"

    def build(roles = 'all')
      Pvcglue::Stack.build(roles)
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
      system(%(ssh -t deploy@#{node_data[:public_ip]} "cd #{working_dir} && echo 'Starting #{options[:stage].upcase} Rails console in #{working_dir}' && bundle exec rails c #{options[:stage].downcase}"))

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

    desc "db SUBCOMMAND ...ARGS", "db utils"
    method_option :stage, :aliases => "-s"
    subcommand "db", Db

    desc "ssl SUBCOMMAND ...ARGS", "manage ssl certificates"
    method_option :stage, :required => true, :aliases => "-s"
    subcommand "ssl", Ssl


    desc "maintenance", "enable or disable maintenance mode"
    method_option :stage, :required => true, :aliases => "-s"

    def maintenance(mode)
      raise(Thor::Error, "invalid maintenance mode :(  (Hint:  try on or off.)") unless mode.in?(%w(on off))
      Pvcglue.cloud.maintenance_mode = mode
      Pvcglue::Packages.apply(:maintenance_mode, :maintenance, Pvcglue.cloud.nodes_in_stage('lb'))
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

    desc "bypass", "enable or disable maintenance mode bypass for developers"
    method_option :stage, :required => true, :aliases => "-s"

    def bypass(mode)
      raise(Thor::Error, "invalid maintenance bypass mode :(  (Hint:  try on or off.)") unless mode.in?(%w(on off))
      Pvcglue.cloud.bypass_mode = mode
      Pvcglue::Packages.apply(:bypass_mode, :maintenance, Pvcglue.cloud.nodes_in_stage('lb'))
    end

    desc "b", "enable or disable maintenance mode bypass for developers"
    method_option :stage, :required => true, :aliases => "-s"

    def b(mode)
      bypass(mode)
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
      system("ssh -p #{Pvcglue.cloud.port_in_context(:shell)} deploy@#{node_data[:public_ip]}")
    end

    desc "s", "shell"
    method_option :stage, :required => true, :aliases => "-s"

    def s(server='web')
      sh(server)
    end

    desc "deploy", "deploy the app"
    method_option :stage, :required => true, :aliases => "-s"

    def deploy
      Pvcglue::Capistrano.deploy
    end

    desc "rake", "run rake task on remote stage"
    method_option :stage, :required => true, :aliases => "-s"

    def rake(*tasks)
      if Pvcglue.cloud.stage_name == 'production'
      # if Pvcglue.cloud.stage_name == 'local'
        raise(Thor::Error, "\nDidn't think so!\n") unless yes?("\n\nStop!  Think!  Are you sure you want to do this on the #{Pvcglue.cloud.stage_name} stage? (y/N)")
      end
      Pvcglue::Capistrano.rake(tasks)
    end

    desc "pvcify", "update capistrano, database.yml and other configurations"
    method_option :stage, :required => true, :aliases => "-s"

    def pvcify
      Pvcglue::Pvcify.run
    end

    desc "start", "start local virtual machines (build first, if required)"
    method_option :stage, :required => true, :aliases => "-s"

    def start
      Pvcglue::Local.start
    end

    desc "up", "start; bootstrap; pvcify; build; deploy"
    method_option :stage, :required => true, :aliases => "-s"

    def up
      Pvcglue::Local.up
    end

    desc "stop", "shut down local virtual machines"
    method_option :stage, :required => true, :aliases => "-s"

    def stop
      Pvcglue::Local.stop
    end

    desc "restart", "stop and then start local virtual machines"
    method_option :stage, :required => true, :aliases => "-s"

    def restart
      Pvcglue::Local.restart
    end

    desc "destroy", "destory local virtual machines"
    method_option :stage, :required => true, :aliases => "-s"

    def destroy
      Pvcglue::Local.destroy
    end

    desc "suspend", "suspend local virtual machines"
    method_option :stage, :required => true, :aliases => "-s"

    def suspend
      Pvcglue::Local.suspend
    end

    desc "status", "show status of local virtual machines"
    method_option :stage, :required => true, :aliases => "-s"

    def status
      Pvcglue::Local.status
    end

    desc "kill", "force shutdown (power off) local virtual machines - may cause data corruption"
    method_option :stage, :required => true, :aliases => "-s"

    def kill
      Pvcglue::Local.kill
    end

    desc "rebuild", "destroy, build and start local virtual machines"
    method_option :stage, :required => true, :aliases => "-s"

    def rebuild
      Pvcglue::Local.rebuild
    end

    desc "update_config", "debug use"
    method_option :stage, :required => true, :aliases => "-s"

    def update_config
      Pvcglue::Local.update_local_config_from_cache
    end


  end


end
