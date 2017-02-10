module Pvcglue
  class Packages
    class Manager < Pvcglue::Packages

      def installed?
        result = connection.run_get_stdout!(user_name, '', %Q(cd #{manager_dir} && git status)) =~ /working directory clean/
        result = result && connection.file_exists?(user_name, manager_filename)
      end

      def install!
        connection.mkdir_p(user_name, manager_dir, nil, nil, 700)

        connection.ssh!(user_name, '', 'git config --global user.name pvc_manager')
        connection.ssh!(user_name, '', 'git config --global --global user.email pvc_manager@pvc.local')
        connection.ssh!(user_name, '', "git init #{Pvcglue::Manager.manager_dir}")

        # TODO:  Create example configuration file, if none exists
        connection.write_to_file(user_name, "#{Time.now.utc.to_s}\n", manager_filename)
        connection.ssh!(user_name, '', %Q(cd #{manager_dir} && git status))
        connection.ssh!(user_name, '', %Q(cd #{manager_dir} && git add -A && git commit --author="$PVCGLUE_USER <>" -m "Change configuration"))
        connection.ssh!(user_name, '', %Q(cd #{manager_dir} && git status))
        connection.ssh!(user_name, '', %Q(cd #{manager_dir} && git log --pretty=format:"%h - %an, %ar : %s" && echo))

      end

      def manager_dir
        Pvcglue::Manager.manager_dir
      end

      def manager_filename
        File.join(manager_dir, 'test.txt')
      end

      def self.push_configuration
        ### Resume here
      end

      def self.pull_configuration

      end

    end
  end
end
