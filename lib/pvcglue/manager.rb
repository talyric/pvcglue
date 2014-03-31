module Pvcglue
  class PvcManager
    def initialize
      puts "init here..."
    end

    def manager_node
      {manager: {public_ip: Pvcglue.configuration.cloud_manager}}
    end

    def bootstrap
      Pvcglue::Packages.apply('bootstrap-manager'.to_sym, manager_node, 'root')
    end

    def push
      Pvcglue::Packages.apply('manager-push'.to_sym, manager_node, 'pvcglue')
    end
  end

end
