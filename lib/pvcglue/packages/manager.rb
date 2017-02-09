module Pvcglue
  class Packages
    class Manager < Pvcglue::Packages
      # MANAGER_DIR = '~/manager'
      # MANAGER_FILENAME = '~/manager'

      def installed?
        false
      end

      def post_install_check?
        result = connection.file_exists?(user_name, 'zzzaaa')
      end

      def install!
        manager_dir = Pvcglue::Manager.manager_dir
        connection.mkdir_p(user_name, manager_dir, nil, nil, 700)
        #git config --global user.name "Emma Paris"
        #git config --global user.email "eparis@atlassian.com"
        connection.ssh!(user_name, '', 'git config --global user.name pvc_manager')
        connection.ssh!(user_name, '', 'git config --global --global user.email pvc_manager@pvc.local')
        connection.ssh!(user_name, '', "git init #{Pvcglue::Manager.manager_dir}")
        # RESUME HERE
      end

      def sync_maintenance_files
      end
    end
  end
end
