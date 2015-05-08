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
      @data = data.with_indifferent_access # We may not want this dependency.
    end

    def current_node
      raise "Current node not set." if @current_node.nil?
      @current_node
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

    def stage
      # puts data[app_name].inspect
      # puts data[app_name][:stages].inspect
      # puts data[app_name][:stages][stage_name].inspect
      data[app_name][:stages][stage_name]
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
      # puts (stage_roles.values.each_with_object({}) { |node, nodes| nodes.merge!(node) }).inspect
      # stage_roles.values.each_with_object({}) { |node, nodes| nodes.merge!(node) }
      nodes = stage_roles.each_with_object({}) do |(role, node), nodes|
        if role_filter == 'all' || role == role_filter
          nodes.merge!(node)
        end
      end
      # puts nodes.inspect
      # puts "nodes_in_stage: only first returned"+"!*"*80
      # out = {}
      # out["memcached"] = nodes["memcached"]
      # puts out.inspect
      # out
    end

    # ENV['PVC_DEPLOY_TO_BASE'] = stage_data[:deploy_to] || '/sites'
    def deploy_to_base_dir
      # stage[:deploy_to] || '/sites' # TODO:  verify if server setup supports `:deploy_to` override
      Pvcglue.configuration.web_app_base_dir # TODO:  server setup does not yet support `:deploy_to` override, and would have to be refactored at a higher level than stage.
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

    def env_file_name
      File.join(deploy_to_app_shared_dir, ".env.#{stage_name_validated}")
    end

    def deploy_to_app_current_public_dir
      File.join(deploy_to_app_current_dir, 'public')
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
      data[app_name][:authorized_keys]
    end

    def ssh_ports
      ports = []
      from_all = data[app_name][:ssh_allowed_from_all_port].to_i
      ports << from_all if from_all > 0
      ports
    end

    def timezone
      data[app_name][:time_zone] || 'America/Los_Angeles'
    end

    def exclude_tables
      data[app_name][:excluded_db_tables] || ['versions']
    end

    def firewall_allow_incoming_on_port
      # These ports allow incoming connections from any ip address
      ports = []
      from_all = data[app_name][:ssh_allowed_from_all_port].to_i
      ports << from_all if from_all > 0
      ports.concat [80, 443] if current_node.values.first[:allow_public_access]
      ports
    end

    def firewall_allow_incoming_from_ip
      # Incoming connections to any port are allowed from these ip addresses
      addresses = dev_ip_addresses
      addresses.concat(stage_internal_addresses)
      # puts addresses.inspect
      addresses
    end

    def dev_ip_addresses
      data[app_name][:dev_ip_addresses].values.each_with_object([]) { |address, addresses| addresses << address }
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

    def ssl_mode
      stage[:ssl].to_sym || :none
    end

    def delayed_job_args
      stage[:delayed_job_args]
    end

    def repo_url
      data[app_name][:repo_url]
    end

    def client_header_timeout
      data[app_name][:client_header_timeout] || stage[:client_header_timeout] || "60s"
    end

    def client_body_timeout
      data[app_name][:client_body_timeout] || stage[:client_body_timeout] || "60s"
    end

    def proxy_read_timeout
      data[app_name][:proxy_read_timeout] || stage[:proxy_read_timeout] || "60s"
    end

    def proxy_send_timeout
      data[app_name][:proxy_send_timeout] || stage[:proxy_send_timeout] || "60s"
    end

    def client_max_body_size
      data[app_name][:client_max_body_size] || stage[:client_max_body_size] || "1m"
    end

    def swapfile_size
      data[app_name][:swapfile_size] || stage[:swapfile_size] || 1024
    end

    def gems
      data[app_name][:gems] || {}
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
          port = data[app_name][:ssh_allowed_from_all_port] || "22"
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
  end

  def self.cloud
    @cloud ||= Cloud.new
  end

  def self.cloud=(config)
    @cloud = config
  end


end
