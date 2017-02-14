require "active_support"
require "active_support/core_ext" # for `with_indifferent_access`

module Pvcglue
  class Cloud
    attr_accessor :data
    attr_accessor :current_node
    attr_accessor :current_hostname
    attr_accessor :maintenance_mode
    attr_accessor :bypass_mode
    attr_accessor :stage_env
    attr_accessor :passenger_ruby
    attr_accessor :port_in_node_context

    def data
      ::Pvcglue::Manager.initialize_cloud_data unless @data
      @data
    end

    def data=(data)
      # @data = data.with_indifferent_access # We may not want this dependency.
      # @data = data.to_dot # We may not want this dependency.
      # @data = Hashie::Mash.new(data) # We may not want this dependency.
      @data = ::SafeMash.new(data)
    end

    def current_node
      raise "Current node not set." if @current_node.nil?
      @current_node
    end

    def current_node_without_nil_check
      @current_node
    end

    def current_node_data
      current_node.values.first
    end


    def current_hostname
      raise "Current current_hostname not set." if @current_hostname.nil?
      @current_hostname
    end

    def set_stage(stage)
      @stage_name = stage
      @stage_name.downcase! if @stage_name
    end

    def stage_name
      @stage_name
    end

    def stage_name_validated
      # TODO:  Document better or fix root cause
      # Work-around for orca file packages that are loaded when required, but stage_name is not going to be used
      # raise "stage_name is required in this context" unless @stage_name
      @stage_name
    end

    def old_stage
      # puts project.inspect
      # puts project[:stages].inspect
      # puts project[:stages][stage_name].inspect
      project[:stages][stage_name]
    end

    def stage_roles
      raise("Stage not defined:  #{stage_name}.") if stage.nil?
      # raise(Thor::Error, "Stage not defined:  #{stage_name}.") if stage.nil?
      stage[:roles]
    end

    def local_file_name
      File.join(application_dir, Pvcglue::Manager.cloud_data_file_name_base)
    end

    def env_local_file_name
      File.join(application_dir, Pvcglue::Env.stage_env_file_name_base)
    end

    def application_dir
      Pvcglue.configuration.application_dir
    end

    # find node by full node_name or by matching prefix of node_name
    def find_node(node_name, raise_error = true)
      puts "*"*80
      raise(Thor::Error, "Node not specified.") if node_name.nil? || node_name.empty?
      return {node_name => nodes_in_stage[node_name]} if nodes_in_stage[node_name]
      puts "-"*80
      nodes_in_stage.each do |key, value|
        puts key
        return {key => value} if key.start_with?(node_name)
      end
      raise("Not found:  #{node_name} in #{stage_name}.") if raise_error
      # raise(Thor::Error, "Not found:  #{node_name} in #{stage_name}.")
    end

    def nodes_in_stage(role_filter = 'all')
      # # puts (stage_roles.values.each_with_object({}) { |node, nodes| nodes.merge!(node) }).inspect
      # # stage_roles.values.each_with_object({}) { |node, nodes| nodes.merge!(node) }
      # nodes = stage_roles.each_with_object({}) do |(role, node), nodes|
      #   if role_filter == 'all' || role == role_filter
      #     nodes.merge!(node)
      #   end
      # end
      # # puts nodes.inspect
      # # puts "nodes_in_stage: only first returned"+"!*"*80
      # # out = {}
      # # out["memcached"] = nodes["memcached"]
      # # puts out.inspect
      # # out
      if role_filter == 'all'
        minions
      else
        minions.select { |minion_name, minion| minion.has_role?(role_filter) }
      end
    end

    # ENV['PVC_DEPLOY_TO_BASE'] = stage_data[:deploy_to] || '/sites'
    def deploy_to_base_dir
      # stage[:deploy_to] || '/sites' # TODO:  verify if server setup supports `:deploy_to` override
      web_app_base_dir # TODO:  server setup does not yet support `:deploy_to` override, and would have to be refactored at a higher level than stage.
    end

    # ENV['PVC_DEPLOY_TO_APP'] = "#{ENV['PVC_DEPLOY_TO_BASE']}/#{ENV['PVC_APP_NAME']}/#{ENV['PVC_STAGE']}"
    def deploy_to_app_dir
      File.join(deploy_to_base_dir, app_name, stage_name)
    end

    def deploy_to_app_current_dir
      File.join(deploy_to_app_dir, 'current')
    end

    def deploy_to_app_shared_dir
      File.join(deploy_to_app_dir, 'shared')
    end

    def deploy_to_app_shared_pids_dir
      File.join(deploy_to_app_shared_dir, 'pids')
    end

    def env_file_name
      File.join(deploy_to_app_shared_dir, ".env.#{stage_name_validated}")
    end

    def deploy_to_app_current_public_dir
      File.join(deploy_to_app_current_dir, 'public')
    end

    def deploy_to_app_current_bin_dir
      File.join(deploy_to_app_current_dir, Pvcglue.configuration.rails_bin_dir)
    end

    def maintenance_files_dir
      File.join(deploy_to_app_dir, 'maintenance')
    end

    def maintenance_mode_file_name
      File.join(maintenance_files_dir, 'maintenance.on')
    end

    def maintenance_bypass_mode_file_name
      File.join(maintenance_files_dir, 'maintenance_bypass.off')
    end

    def deploy_to_app_current_temp_dir
      File.join(deploy_to_app_current_dir, 'tmp')
    end

    def restart_txt_file_name
      File.join(deploy_to_app_current_temp_dir, 'restart.txt')
    end

    def app_name
      Pvcglue.configuration.application_name
    end

    def authorized_keys
      project[:authorized_keys]
    end

    def ssh_ports
      ports = []
      from_all = project[:ssh_allowed_from_all_port].to_i
      ports << from_all if from_all > 0
      ports
    end

    def timezone
      project[:time_zone] || 'America/Los_Angeles'
    end

    def exclude_tables
      project[:excluded_db_tables] || ['versions']
    end

    def firewall_allow_incoming_on_port
      raise 'Not used currently > 0.9'
      # These ports allow incoming connections from any ip address
      ports = []
      from_all = project[:ssh_allowed_from_all_port].to_i
      ports << from_all if from_all > 0
      ports.concat [80, 443] if current_node.values.first[:allow_public_access]
      ports.concat ["2000:3000"] if stage_name == 'local'
      ports
    end

    def firewall_allow_incoming_from_ip
      raise 'Not used currently > 0.9'
      # Incoming connections to any port are allowed from these ip addresses
      addresses = dev_ip_addresses
      addresses.concat(stage_internal_addresses)
      # puts addresses.inspect
      if stage_name == 'local'
        addresses << Pvcglue::Local.vagrant_config # Yes, this is a hack, and should be refactored.  :)
      end
      # puts addresses.inspect
      addresses
    end

    def dev_ip_addresses
      return ['127.0.0.1']
      # TODO:  Add this functionality back in later
      project[:dev_ip_addresses].values.each_with_object([]) { |address, addresses| addresses << address }
    end

    def stage_internal_addresses
      nodes_in_stage.values.each_with_object([]) do |value, addresses|
        addresses << value[:public_ip]
        addresses << value[:private_ip] if value[:private_ip]
      end
    end

    # app_stage_name = "#{ENV['PVC_APP_NAME']}_#{ENV['PVC_STAGE']}".downcase
    def app_and_stage_name
      "#{app_name}_#{stage_name}".downcase
    end

    def domains
      stage[:domains]
    end

    def web_nginx_http
      current_node.values.first[:web_nginx_http] || []
    end

    def web_nginx_server
      current_node.values.first[:web_nginx_server] || []
    end

    def ssl_mode
      stage[:ssl].to_sym || :none
    end

    def lb_nginx_load_balancing_method
      stage[:lb_nginx_load_balancing_method]
    end

    def delayed_job_args
      stage[:delayed_job_args]
    end

    def repo_url
      project[:repo_url]
    end

    def dos_conn_limit_per_ip
      project[:dos_conn_limit_per_ip] || stage[:dos_conn_limit_per_ip] || "10"
    end

    def dos_rate
      project[:dos_rate] || stage[:dos_rate] || "1"
    end

    def dos_burst
      project[:dos_burst] || stage[:dos_burst] || "30"
    end

    def additional_linked_dirs
      project[:additional_linked_dirs] || stage[:additional_linked_dirs] || ""
    end

    def client_header_timeout
      project[:client_header_timeout] || stage[:client_header_timeout] || "60s"
    end

    def client_body_timeout
      project[:client_body_timeout] || stage[:client_body_timeout] || "60s"
    end

    def proxy_read_timeout
      project[:proxy_read_timeout] || stage[:proxy_read_timeout] || "60s"
    end

    def proxy_send_timeout
      project[:proxy_send_timeout] || stage[:proxy_send_timeout] || "60s"
    end

    def client_max_body_size
      project[:client_max_body_size] || stage[:client_max_body_size] || "1m"
    end

    def swapfile_size
      project[:swapfile_size] || stage[:swapfile_size] || 1024
    end

    def gems
      project[:gems] || {}
    end

    def db_rebuild
      !!stage[:db_rebuild]
    end

    def nginx_config_path
      '/etc/nginx'
    end

    def nginx_config_ssl_path
      File.join(nginx_config_path, 'ssl')
    end

    def nginx_ssl_crt_file_name
      File.join(nginx_config_ssl_path, "#{app_and_stage_name}.crt")
    end

    def nginx_ssl_key_file_name
      File.join(nginx_config_ssl_path, "#{app_and_stage_name}.key")
    end

    def ssl_crt
      stage[:ssl_crt]
    end

    def ssl_key
      stage[:ssl_key]
    end

    def port_in_context(context)
      case context
        when :bootstrap, :manager
          port = "22"
        when :env, :build, :shell, :deploy, :maintenance
          port = project[:ssh_allowed_from_all_port] || "22"
        else
          raise "Context not specified or invalid"
      end
      puts "Setting port to #{port}"
      @port_in_node_context = port
    end

    def port_in_node_context
      raise "Context not specified or invalid" if @port_in_node_context.nil?
      puts "Setting port_in_node_context to #{@port_in_node_context}"
      @port_in_node_context
    end

    def delayed_job_worker_count
      return 0 unless gems[:delayed_job]
      (stage[:delayed_job_workers] || 1).to_i
    end

    def resque_worker_count
      return 0 unless gems[:resque]
      (stage[:resque_workers] || 1).to_i
    end

    def monit_mailserver
      project[:monit_mailserver] || ""
    end

    def monit_alert
      project[:monit_alert] || ""
    end

    def monit_disk_usage_threshold
      stage[:monit_disk_usage_threshold] || project[:monit_disk_usage_threshold] || "80%"
    end

    def minion_manager_user_name
      'manager'
    end


    # ==============================================================================================

    def manager_minion
      @manager_minion ||= get_manager_minion
    end

    def get_manager_minion
      minion = Pvcglue::Minion.new
      minion.machine_name = 'pvcglue-manager'
      minion.roles = ['manager']
      minion.public_ip = Pvcglue.configuration.cloud_manager
      minion.connection = Pvcglue::Connection.new(minion)
      # minion.root_users = machine.root_users
      # minion.users = machine.users
      # minion.cloud_id = machine.cloud_id
      minion.remote_user_name = minion_manager_user_name
      # minion.all_data = data
      # minion.project = project
      # minion.stage = stage
      # minion.cloud_provider = data.cloud_provider
      # minion.cloud = ::Pvcglue.cloud
      # minion.cloud_provider.name == 'not-supported'
      minion

    end

    # def set_manager_as_project
    #
    #   # raise('project already initialized') if @project
    #   # @project = find_or_raise(data.projects, 'pvcglue_manager')
    #   @app_name_override = 'pvcglue_manager'
    #   set_stage('manager')
    # end

    def reload_minions!
      @data = nil
      @project = nil
      @stage = nil
      @minions = nil
    end

    def web_app_base_dir
      # '/sites'
      "/home/#{minion_user_name}/www"
    end


    def minion_user_name_base
      project[:user_name_base] || 'deploy'
    end

    def minion_user_name
      "#{minion_user_name_base}-#{stage_name}"
    end


    def find_or_raise(data, name, key = 'name')
      found = data.detect { |item| item[key] == name }
      # raise(Thor::Error, "Error:  #{name} not found.") unless found
      unless found
        puts "name=#{name}, key=#{key}, data="
        ap data
        raise("Error:  #{name} not found.")
      end
      found
    end

    def project
      @project ||= begin
        get_project
      end
    end

    def get_project
      find_or_raise(data.projects, @app_name_override || app_name)
    end

    def stage
      @stage ||= begin
        find_or_raise(project.stages, stage_name)
      end
    end

    def minions
      @minions ||= get_minions
    end

    def find_machine(name)
      name.tr!('=', '') # "==dev-lb==" ==> "dev-lb"
      find_or_raise(data.machines, name)
    end

    def get_minions
      minions = ::SafeMash.new
      stage.stack.each do |item|
        # ap item
        machine = find_machine(item.machine_name)
        # ap machine
        minion = minions[machine.name]
        # ap minion
        unless minion
          # TODO:  check for duplicate roles:  ie. 2 web servers with the same id
          minion = Pvcglue::Minion.new
          minion.machine_name = item.machine_name
          minion.roles = []
          minion.private_ip = machine.private_ip
          minion.public_ip = machine.public_ip
          minion.connection = Pvcglue::Connection.new(minion)
          minion.root_users = machine.root_users
          minion.users = machine.users
          minion.cloud_id = machine.cloud_id
          minion.remote_user_name = minion_user_name
          # TODO:  sync all machine options here, automatically
        end
        # ap minion
        # puts "*"*175
        # ap minion.roles
        # ap item.role
        minion.roles << item.role
        # ap minion.roles

        # if item.role_index?
        #   minions
        # end
        # ap minion

        minion.all_data = data
        minion.project = project
        minion.stage = stage
        minion.cloud_provider = data.cloud_provider
        minion.cloud = ::Pvcglue.cloud

        minions[machine.name] = minion
      end
      # ap minions
      minions
    end
  end

  def self.cloud
    @cloud ||= Cloud.new
  end

  def self.cloud=(config)
    @cloud = config
  end


end
