module Pvcglue
  class Cloud
    attr_accessor :data

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
  end

  def self.cloud
    @cloud ||= Cloud.new
  end

  def self.cloud=(config)
    @cloud = config
  end


end
