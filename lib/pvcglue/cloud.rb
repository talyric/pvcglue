require "active_support/core_ext" # for `with_indifferent_access`


module Pvcglue
  class Cloud
    attr_accessor :data

    def data
      ::Pvcglue::PvcManager.new.initialize_cloud_data unless @data
      @data
    end

    def data=(data)
      @data = data.with_indifferent_access
    end

    def set_stage(stage)
      raise "stage name can't be blank" if stage.nil? || stage.empty?
      @stage_name = stage
    end

    def stage_name
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
      @file_name_base ||= "#{Pvcglue.configuration.cloud_name}_#{Pvcglue.configuration.application_name}.pvcglue.json"
    end

    # find node by full node_name or by matching prefix of node_name
    def find_node(node_name)
      puts "*"*80
      return nil if node_name.nil? || node_name.empty?
      return stage_nodes[node_name] if stage_nodes[node_name]
      puts "-"*80
      stage_nodes.each do |key, _|
        puts key
        return stage_nodes[key] if key.start_with?(node_name)
      end
      nil
    end

    def stage_nodes
      # I'm sure there's a better way.
      all = {}
      stage_roles.values.each { |node_group| node_group.each { |key, value| all[key] = value } }
      all
    end
  end

  def self.cloud
    @cloud ||= Cloud.new
  end

  def self.cloud=(config)
    @cloud = config
  end


end
