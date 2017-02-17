require 'thor'
require 'orca'
require 'pvcglue'

module Pvcglue

  class CLI < Thor
    class_option :cloud_manager_override
    class_option :verbose
    class_option :reset_minion_state
    class_option :save_before_upload
    class_option :create_test_cert
    class_option :force_cert

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

    desc "build", "build..."
    method_option :stage, :required => true, :aliases => "-s"

    def build(roles = 'all')
      Pvcglue::Stack.build(Pvcglue.cloud.minions, roles)
    end

    desc "console", "open rails console"
    method_option :stage, :required => true, :aliases => "-s"

    def console(server='web')
      data = Pvcglue.cloud.minions_filtered(server)
      minion_name = data.keys.first
      minion = data.values.first
      working_dir = Pvcglue.cloud.deploy_to_app_current_dir
      Pvcglue.logger.warn("Opening Rails console on #{minion_name} (#{minion.public_ip}) as user '#{minion.remote_user_name}'...")
      Pvcglue.logger.debug("Project root:  #{working_dir}")

      cmd = "cd #{working_dir} && bundle exec rails c #{options[:stage].downcase}"
      # system(%(ssh -t deploy@#{node_data[:public_ip]} "cd #{working_dir} && echo 'Starting #{options[:stage].upcase} Rails console in #{working_dir}' && bundle exec rails c #{options[:stage].downcase}"))
      minion.connection.ssh!(minion.remote_user_name, '-t', cmd)
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
      # Pvcglue.cloud.maintenance_mode = mode
      # Pvcglue::Packages.apply(:maintenance_mode, :maintenance, Pvcglue.cloud.nodes_in_stage('lb'))
      Pvcglue.cloud.minions_filtered('lb').each do |minioin_name, minion|
        Pvcglue::Packages::MaintenanceMode.apply(minion, {maintenance_mode: mode})
      end
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
      Pvcglue::Packages.apply(:bypass_mode, :maintenance, Pvcglue.cloud.minions_filtered('lb'))
    end

    desc "b", "enable or disable maintenance mode bypass for developers"
    method_option :stage, :required => true, :aliases => "-s"

    def b(mode)
      bypass(mode)
    end


    desc "sh", "run interactive shell on node"
    method_option :stage, :required => true, :aliases => "-s"

    def sh(server='web') # `shell` is a Thor reserved word
      data = Pvcglue.cloud.minions_filtered(server)
      minion_name = data.keys.first
      minion = data.values.first
      # puts "*"*80
      # puts node.inspect
      Pvcglue.logger.warn("Connecting to #{minion_name} (#{minion.public_ip}) as user '#{minion.remote_user_name}'...")
      # puts "Connection to #{minion_name} (#{minion.public_ip}) as user '#{minion.remote_user_name}'..."
      # system("ssh -p #{Pvcglue.cloud.port_in_context(:shell)} #{minion.remote_user_name}@#{minion[:public_ip]}")
      minion.connection.ssh!(minion.remote_user_name, '', '')
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
