module Pvcglue
  class Packages
    class Manager < Pvcglue::Packages

      def initialize(minion = nil, options = {})
        minion = Pvcglue.cloud.manager_minion if minion.nil?
        super
      end

      def installed?
        get_minion_state(:manager_installed_at)
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

        set_minion_state(:manager_installed_at, Time.now.utc)
      end

      def post_install_check?
        return false unless connection.file_exists?(user_name, manager_dir)
        return false unless working_directory_clean?
        connection.file_exists?(user_name, manager_test_filename)
      end

      def manager_dir
        Pvcglue::Manager.manager_dir
      end

      def manager_test_filename
        File.join(manager_dir, 'install.log')
      end

      def self.get_configuration
        new.get_configuration
      end

      def self.configuration_exists?
        new.configuration_exists?
      end

      def configuration_exists?
        connection.file_exists?(user_name, ::Pvcglue::Manager.manager_file_name)
      end

      def get_configuration
        # if connection.file_exists?(user_name, ::Pvcglue::Manager.manager_file_name)
        #   data = connection.read_from_file(user_name, ::Pvcglue::Manager.manager_file_name)
        # else
        #   # raise(Thor::Error, "Remote manager file not found:  #{::Pvcglue::Manager.manager_file_name}")
        #   raise("Remote manager file not found:  #{::Pvcglue::Manager.manager_file_name}")
        # end
        data = '' # to use `data` in block
        if Pvcglue.command_line_options[:cloud_manager_override]
          data = File.read(Pvcglue.command_line_options[:cloud_manager_override])
        else
          Pvcglue.filter_verbose do
            data = connection.read_from_file(user_name, ::Pvcglue::Manager.manager_file_name)
          end
        end
        ::Pvcglue.cloud.data = TOML.parse(data)
      end

      def self.push_configuration
        new.push_configuration
      end

      def push_configuration
        raise('Not supported for local manager') if Pvcglue.command_line_options[:cloud_manager_override]

        test_data = File.read(::Pvcglue.cloud.local_file_name)
        ::SafeMash.new(TOML.parse(test_data)) # At least make sure it's valid TOML and that we can load it in

        # TODO:  More in-depth validations

        connection.upload_file(user_name, ::Pvcglue.cloud.local_file_name, ::Pvcglue::Manager.manager_file_name, nil, nil, '600')
        git_commit!
        raise('Error saving configuration') unless working_directory_clean?
        # TODO:  Turn delete back on
        # File.delete(::Pvcglue.cloud.local_file_name)
      end

      def git_commit!
        # connection.ssh!(user_name, '', %Q(cd #{manager_dir} && git add -A && git commit --allow-empty --author="pvc-$PVCGLUE_USER <>" -m "Change configuration")) # Will not work as $PVCGLUE_USER is in the local context here
        connection.ssh!(user_name, '', %Q(cd #{manager_dir} && git add -A && git commit --allow-empty --author="pvc-\\$PVCGLUE_USER <>" -m "Change configuration")) # It's all about context!
        # connection.ssh!(user_name, '', %Q(cd #{manager_dir} && git add -A && git commit --allow-empty --author="pvc-\\`printenv PVCGLUE_USER\\` <>" -m "Change configuration")) # Another way that works...for future reference
      end

      def working_directory_clean?
        connection.run_get_stdout!(user_name, '', %Q(cd #{manager_dir} && git status)) =~ /working directory clean/
      end

      def self.pull_configuration
        new.pull_configuration
        # new(Pvcglue.cloud.manager_minion).pull_configuration
      end

      def pull_configuration
        # ssh REMOTE "sh -c \"(nohup sleep 30; touch nohup-exit) > /dev/null &\""
        # TODO:  Rename to edit_config_start, and create Thor commands to match
        if connection.file_exists?(user_name, ::Pvcglue::Manager.manager_file_name)
          data = connection.read_from_file(user_name, ::Pvcglue::Manager.manager_file_name)
        else
          template = Tilt.new(Pvcglue.template_file_name('pvc_manager.toml.erb'))
          data = template.render(self, minion: minion)
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

      def load_secrets
        connection.read_from_file_if_exists?(user_name, ::Pvcglue::Env.stage_env_file_name)
      end

      def save_secrets(data)
        connection.write_to_file(user_name, data, ::Pvcglue::Env.stage_env_file_name, nil, nil, 600)
        git_commit!
      end

    end
  end
end
