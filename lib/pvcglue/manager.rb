require 'pp'

module Pvcglue
  class PvcManager
    # TODO:  I guess these could all be class methods
    def bootstrap
      Pvcglue::Packages.apply('bootstrap-manager'.to_sym, manager_node, 'root')
    end

    def push
      Pvcglue::Packages.apply('manager-push'.to_sym, manager_node, 'pvcglue')
      clear_cloud_data_cache
    end

    def pull
      Pvcglue::Packages.apply('manager-pull'.to_sym, manager_node, 'pvcglue')
      clear_cloud_data_cache
    end

    def initialize_cloud_data
      unless read_cached_cloud_data
        Pvcglue::Packages.apply('manager-get-all'.to_sym, manager_node, 'pvcglue')
        write_cloud_data_cache
      end
    end

    def write_cloud_data_cache
      File.write(Pvcglue.configuration.cloud_cache_file_name, Pvcglue.cloud.data.to_json)
    end

    def read_cached_cloud_data
      # TODO:  Expire cache after given interval
      if File.exists?(Pvcglue.configuration.cloud_cache_file_name)
        data = File.read(Pvcglue.configuration.cloud_cache_file_name)
        Pvcglue.cloud.data = JSON.parse(data)
        return true
      end
      false
    end

    def clear_cloud_data_cache
      if File.exists?(Pvcglue.configuration.cloud_cache_file_name)
        File.delete(Pvcglue.configuration.cloud_cache_file_name)
      end
    end

    def show
      initialize_cloud_data
      # pp Pvcglue.cloud.data
    end

    def manager_node
      {manager: {public_ip: Pvcglue.configuration.cloud_manager}}
    end

  end

end
