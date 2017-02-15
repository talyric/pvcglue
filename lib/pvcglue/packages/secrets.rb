module Pvcglue
  class Packages
    class Secrets < Pvcglue::Packages
      def installed?
        false
      end

      def install!
        connection.write_to_file_from_template(user_name, 'web.env.erb', Pvcglue.cloud.env_file_name, nil, nil, '0640') # TODO:  Double check permissions
        restart_web_app!
      end

      def post_install_check?
        true
      end

      def restart_web_app!
        if connection.file_exists?(user_name, Pvcglue.cloud.deploy_to_app_current_temp_dir)
          connection.ssh!(user_name, '', "touch #{Pvcglue.cloud.restart_txt_file_name}")
        end
      end

      def self.load_for_stage
        data = Pvcglue::Packages::Manager.new.load_secrets
        data = '' if data.nil?
        Pvcglue.cloud.stage_env = TOML.parse(data)
      end

      def self.save_for_stage
        data = TOML.dump(Pvcglue.cloud.stage_env)
        Pvcglue::Packages::Manager.new.save_secrets(data)
      end
    end
  end
end
