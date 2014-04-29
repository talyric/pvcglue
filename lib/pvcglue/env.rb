require 'pp'

module Pvcglue
  class Env < Thor

    desc "push", "push"

    def push
      Pvcglue::Packages.apply('env-push'.to_sym, Pvcglue::Manager.manager_node, 'pvcglue')
      self.class.clear_stage_env_cache
    end

    desc "pull", "pull"

    def pull
      Pvcglue::Packages.apply('env-pull'.to_sym, Pvcglue::Manager.manager_node, 'pvcglue')
      self.class.clear_stage_env_cache
    end

    desc "show", "show"

    def show
      self.class.initialize_stage_env
      pp Pvcglue.cloud.stage_env
    end

    # ------------------------------------------------------------------------------------------------------------------

    def self.initialize_stage_env
      unless read_cached_stage_env
        Pvcglue::Packages.apply('env-get-stage'.to_sym, Pvcglue::Manager.manager_node, 'pvcglue')
        write_stage_env_cache
      end
      if Pvcglue.cloud.stage_env.empty?
        Pvcglue.cloud.stage_env = stage_env_defaults
        save_stage_env
      end
    end

    def self.save_stage_env
      Pvcglue::Packages.apply('env-set-stage'.to_sym, Pvcglue::Manager.manager_node, 'pvcglue')
      write_stage_env_cache
    end

    def self.stage_env_defaults
      {
          'DB_USER_POSTGRES_USERNAME' => "#{Pvcglue.cloud.app_name}_#{Pvcglue.cloud.stage_name_validated}",
          'DB_USER_POSTGRES_PASSWORD' => new_password
      }
    end

    def self.new_password
      "a#{SecureRandom.hex(16)}"
    end

    def self.write_stage_env_cache
      File.write(stage_env_cache_file_name, TOML.dump(Pvcglue.cloud.stage_env))
    end

    def self.read_cached_stage_env
      # TODO:  Only use cache in development of gem, do not cache by default, use Manager config
      if File.exists?(stage_env_cache_file_name)
        stage_env = File.read(stage_env_cache_file_name)
        Pvcglue.cloud.stage_env = TOML.parse(stage_env)
        return true
      end
      false
    end

    def self.stage_env_file_name
      File.join(Pvcglue::Manager.manager_dir, stage_env_file_name_base )
    end

    def self.stage_env_file_name_base
      @stage_env_file_name_base ||= "#{Pvcglue.configuration.cloud_name}_#{Pvcglue.configuration.application_name}_#{Pvcglue.cloud.stage_name_validated}.env.toml"
    end

    def self.stage_env_cache_file_name
      File.join(Pvcglue.configuration.tmp_dir, "pvcglue_cache_#{stage_env_file_name_base}")
    end

    def self.clear_stage_env_cache
      File.delete(stage_env_cache_file_name) if File.exists?(stage_env_cache_file_name)
    end


  end

end