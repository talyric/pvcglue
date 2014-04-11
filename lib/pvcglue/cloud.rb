require "active_support/core_ext" # for `with_indifferent_access`


module Pvcglue
  class Cloud
    attr_accessor :data

    def data
      ::Pvcglue::PvcManager.new.initialize_cloud_data unless @data
      @data
    end

    def data=(data)
      @data = data.with_indifferent_access # We may not want this dependency.
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
      return nil if node_name.nil? || node_name.empty?
      return nodes_in_stage[node_name] if nodes_in_stage[node_name]
      puts "-"*80
      nodes_in_stage.each do |key, value|
        puts key
        return {key => value} if key.start_with?(node_name)
      end
      nil
    end

    def nodes_in_stage
      # puts (stage_roles.values.each_with_object({}) { |node, nodes| nodes.merge!(node) }).inspect
      stage_roles.values.each_with_object({}) { |node, nodes| nodes.merge!(node) }
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
      File.join(deploy_to_app_dir,'current')
    end

    def app_name
      Pvcglue.configuration.application_name
    end
  end

  def self.cloud
    @cloud ||= Cloud.new
  end

  def self.cloud=(config)
    @cloud = config
  end


end
