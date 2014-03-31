require 'pp'

module Pvcglue
  class PvcManager
    # TODO:  I guess these could all be class methods
    def bootstrap
      Pvcglue::Packages.apply('bootstrap-manager'.to_sym, manager_node, 'root')
    end

    def push
      Pvcglue::Packages.apply('manager-push'.to_sym, manager_node, 'pvcglue')
    end

    def pull
      Pvcglue::Packages.apply('manager-pull'.to_sym, manager_node, 'pvcglue')
    end

    def initialize_cloud_data
      Pvcglue::Packages.apply('manager-get-all'.to_sym, manager_node, 'pvcglue')
    end

    def show
      initialize_cloud_data
      pp Pvcglue.cloud.data
    end

    def manager_node
      {manager: {public_ip: Pvcglue.configuration.cloud_manager}}
    end

  end

end
