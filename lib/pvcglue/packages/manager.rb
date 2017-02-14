module Pvcglue
  class Packages
    class Manager < Pvcglue::Packages

      def installed?
        return false unless connection.file_exists?(user_name, manager_dir)
        return false unless working_directory_clean?
        connection.file_exists?(user_name, manager_test_filename)
      end

      def install!
        connection.mkdir_p(user_name, manager_dir, nil, nil, 700)

        connection.ssh!(user_name, '', 'git config --global user.name pvc_manager')
        connection.ssh!(user_name, '', 'git config --global --global user.email pvc_manager@pvc.local')
        connection.ssh!(user_name, '', "git init #{Pvcglue::Manager.manager_dir}")

        # TODO:  Create example configuration file, if none exists
        connection.write_to_file(user_name, "#{Time.now.utc.to_s}\n", manager_test_filename)
        connection.ssh!(user_name, '', %Q(cd #{manager_dir} && git status))
        git_commit!
        connection.ssh!(user_name, '', %Q(cd #{manager_dir} && git status))
        # https://git-scm.com/book/en/v2/Git-Basics-Viewing-the-Commit-History
        connection.ssh!(user_name, '', %Q(cd #{manager_dir} && git log --pretty=format:"%h - %an, %ar : %s" && echo))

      end

      def manager_dir
        Pvcglue::Manager.manager_dir
      end

      def manager_test_filename
        File.join(manager_dir, 'install.log')
      end

      def self.get_configuration
        new(Pvcglue.cloud.manager_minion).get_configuration
      end

      def get_configuration
        # if connection.file_exists?(user_name, ::Pvcglue::Manager.manager_file_name)
        #   data = connection.read_from_file(user_name, ::Pvcglue::Manager.manager_file_name)
        # else
        #   # raise(Thor::Error, "Remote manager file not found:  #{::Pvcglue::Manager.manager_file_name}")
        #   raise("Remote manager file not found:  #{::Pvcglue::Manager.manager_file_name}")
        # end
        data = connection.read_from_file(user_name, ::Pvcglue::Manager.manager_file_name)
        ::Pvcglue.cloud.data = TOML.parse(data)
      end

      def self.push_configuration
        new(Pvcglue.cloud.manager_minion).push_configuration
      end

      def push_configuration
        connection.upload_file(user_name, ::Pvcglue.cloud.local_file_name, ::Pvcglue::Manager.manager_file_name, nil, nil, '600')
        git_commit!
        raise('Error saving configuration') unless working_directory_clean?
        File.delete(::Pvcglue.cloud.local_file_name)
      end

      def git_commit!
        connection.ssh!(user_name, '', %Q(cd #{manager_dir} && git add -A && git commit --author="pvc_$PVCGLUE_USER <>" -m "Change configuration"))
      end

      def working_directory_clean?
        connection.run_get_stdout!(user_name, '', %Q(cd #{manager_dir} && git status)) =~ /working directory clean/
      end

      def self.pull_configuration
        new(Pvcglue.cloud.manager_minion).pull_configuration
      end

      def pull_configuration
        # TODO:  Rename to edit_config_start, and create Thor commands to match
        if connection.file_exists?(user_name, ::Pvcglue::Manager.manager_file_name)
          data = connection.read_from_file(user_name, ::Pvcglue::Manager.manager_file_name)
        else
          data = "# Pvcglue manager configuration file\n\n"
        end
        file_name = ::Pvcglue.cloud.local_file_name
        if File.exist?(file_name)
          backup_file_name = ::Pvcglue.configuration.versioned_filename(file_name)
          File.rename(file_name, backup_file_name)
          Pvcglue.logger.info("Existing local configuration file saved to #{backup_file_name}")
        end
        File.write(file_name, data)
        puts "Configuration saved to #{file_name}.  Now edit it and push it back up."
      end
    end
  end
end
