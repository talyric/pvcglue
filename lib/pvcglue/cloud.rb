require "active_support/core_ext" # for `with_indifferent_access`


module Pvcglue
  class Cloud
    attr_accessor :data
    attr_accessor :current_node

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

    def set_stage(stage)
      @stage_name = stage
    end

    def stage_name
      raise "stage not set :( " if @stage_name.nil? || @stage_name.empty?
      @stage_name
    end

    def stage
      #puts data[:application].inspect
      #puts data[:application][:stages].inspect
      #puts data[:application][:stages][stage_name].inspect
      data[:application][:stages][stage_name]
    end

    def stage_roles
      raise(Thor::Error, "Stage not defined:  #{stage_name}.") if stage.nil?
      stage[:roles]
    end

    def local_file_name
      File.join(application_dir, file_name_base)
    end

    def manager_file_name
      File.join('/home/pvcglue/.pvc_manager', file_name_base)
    end

    def application_dir
      Dir.pwd
    end

    def file_name_base
      @file_name_base ||= "#{Pvcglue.configuration.cloud_name}_#{Pvcglue.configuration.application_name}.pvcglue.toml"
    end

    # find node by full node_name or by matching prefix of node_name
    def find_node(node_name)
      puts "*"*80
      raise(Thor::Error, "Node not specified.") if node_name.nil? || node_name.empty?
      return nodes_in_stage[node_name] if nodes_in_stage[node_name]
      puts "-"*80
      nodes_in_stage.each do |key, value|
        puts key
        return {key => value} if key.start_with?(node_name)
      end
      raise(Thor::Error, "Not found:  #{node_name} in #{stage_name}.")
    end

    def nodes_in_stage
      # puts (stage_roles.values.each_with_object({}) { |node, nodes| nodes.merge!(node) }).inspect
      # stage_roles.values.each_with_object({}) { |node, nodes| nodes.merge!(node) }
      nodes = stage_roles.values.each_with_object({}) { |node, nodes| nodes.merge!(node) }
      # puts nodes.inspect
      # puts "nodes_in_stage: only first returned"+"!*"*80
      # out = {}
      # out["memcached"] = nodes["memcached"]
      # puts out.inspect
      # out
    end

    # ENV['PVC_DEPLOY_TO_BASE'] = stage_data[:deploy_to] || '/sites'
    # ENV['PVC_DEPLOY_TO_APP'] = "#{ENV['PVC_DEPLOY_TO_BASE']}/#{ENV['PVC_APP_NAME']}/#{ENV['PVC_STAGE']}"

    def deploy_to_base_dir
      stage[:deploy_to] || '/sites' # TODO:  verify if server setup supports `:deploy_to` override
    end

    def deploy_to_app_dir
      File.join(deploy_to_base_dir, app_name, stage_name)
    end

    def deploy_to_app_current_dir
      File.join(deploy_to_app_dir, 'current')
    end

    def app_name
      Pvcglue.configuration.application_name
    end

    def authorized_keys
      data[:application][:authorized_keys]
    end

    def ssh_ports
      ports = []
      from_all = data[:application][:ssh_allowed_from_all_port].to_i
      ports << from_all if from_all > 0
      ports
    end

    def timezone
      data[:application][:time_zone] || 'America/Los_Angeles'
    end

    def firewall_allow_incoming_on_port
      # These ports allow incoming connections from any ip address
      ports = []
      from_all = data[:application][:ssh_allowed_from_all_port].to_i
      ports << from_all if from_all > 0
      ports << [80, 443] if current_node[:allow_public_access]
      ports
    end

    def firewall_allow_incoming_from_ip
      # Incoming connections to any port are allowed from these ip addresses
      addresses = data[:application][:allowed_ip_addresses].values.each_with_object([]) { |address, addresses| addresses << address }
      addresses.concat(stage_internal_addresses)
      puts addresses.inspect
      addresses
    end

    def stage_internal_addresses
      nodes_in_stage.values.each_with_object([]) do |value, addresses|
        addresses << value[:public_ip]
        addresses << value[:private_ip] if value[:private_ip]
      end
    end
  end

  def self.cloud
    @cloud ||= Cloud.new
  end

  def self.cloud=(config)
    @cloud = config
  end


end
