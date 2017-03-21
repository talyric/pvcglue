require 'pp'

module Pvcglue
  class Env < Thor

    desc "push", "push"

    def push
      raise('Not implemented')
      # Pvcglue::Packages.apply('env-push'.to_sym, :manager, Pvcglue::Manager.manager_node, 'pvcglue')
      # self.class.clear_stage_env_cache
      # Pvcglue::Packages.apply('app-env-file'.to_sym, :env, Pvcglue.cloud.nodes_in_stage('web'))
    end

    desc "pull", "pull"

    def pull
      raise('Not implemented')
      # Pvcglue::Packages.apply('env-pull'.to_sym, :manager, Pvcglue::Manager.manager_node, 'pvcglue')
      # self.class.clear_stage_env_cache
    end

    desc "list", "list"

    def list
      self.class.initialize_stage_env
      Pvcglue.cloud.stage_env.each { |key, value| puts "#{key}=#{value}" }
    end

    desc "default", "reset env to default.  Destructive!!!"

    def default
      if yes?("Are you sure?")
        Pvcglue.cloud.stage_env = Pvcglue::Env.stage_env_defaults
        Pvcglue::Env.save_stage_env
      end
    end

    desc "set", "set environment variable(s) for the stage XYZ=123 [ZZZ=321]"

    def set(*args)
      self.class.initialize_stage_env
      Pvcglue.logger.debug { args.each { |arg| arg.inspect } }
      options = Hash[args.each.map { |l| l.chomp.split('=') }]
      Pvcglue.logger.debug { options.inspect }
      Pvcglue.cloud.stage_env.merge!(options)
      self.class.save_stage_env
      self.class.apply_changes
    end

    desc "unset", "remove environment variable(s) for the stage XYZ [ZZZ]"

    def unset(*args)
      self.class.initialize_stage_env
      args.each { |arg| puts "WARNING:  Key '#{arg}' not found." unless Pvcglue.cloud.stage_env.delete(arg) }
      self.class.save_stage_env
      self.class.apply_changes
    end

    desc "rm", "alternative to unset"

    def rm(*args)
      unset(*args)
    end


    # ------------------------------------------------------------------------------------------------------------------

    def self.initialize_stage_env
      Pvcglue::Packages::Secrets.load_for_stage
      # unless read_cached_stage_env
      #   Pvcglue::Packages.apply('env-get-stage'.to_sym, :manager, Pvcglue::Manager.manager_node, 'pvcglue')
      #   write_stage_env_cache
      # end
      # TODO:  Warn DB_USER_POSTGRES_HOST IP address does not exist in the configured machines

      merged = stage_env_defaults.merge(Pvcglue.cloud.stage_env)
      if merged != Pvcglue.cloud.stage_env
        Pvcglue.cloud.stage_env = merged
        save_stage_env
      end
    end

    def self.save_stage_env
      Pvcglue::Packages::Secrets.save_for_stage
      # Pvcglue::Packages.apply('env-set-stage'.to_sym, :manager, Pvcglue::Manager.manager_node, 'pvcglue')
      # write_stage_env_cache
    end

    def self.stage_env_defaults
      defaults = {}

      defaults['RAILS_SECRET_TOKEN'] = SecureRandom.hex(64) # From rails/railties/lib/rails/tasks/misc.rake
      defaults['SECRET_KEY_BASE'] = SecureRandom.hex(64) # From rails/railties/lib/rails/tasks/misc.rake

      # Don't set a default until we have a provisioned server
      if db_host
        defaults['DB_USER_POSTGRES_HOST'] = db_host
        defaults['DB_USER_POSTGRES_PORT'] = '5432'
        defaults['DB_USER_POSTGRES_USERNAME'] = "#{Pvcglue.cloud.app_name}_#{Pvcglue.cloud.stage_name_validated}"
        defaults['DB_USER_POSTGRES_DATABASE'] = "#{Pvcglue.cloud.app_name}_#{Pvcglue.cloud.stage_name_validated}"
        defaults['DB_USER_POSTGRES_PASSWORD'] = new_password
      end

      # Don't set a default until we have a provisioned server
      if memcached_host
        defaults['MEMCACHE_SERVERS'] = memcached_host
      end

      # Don't set a default until we have a provisioned server
      if redis_url
        defaults['REDIS_URL'] = redis_url
      end

      defaults
    end

    def self.db_host
      # Assume first pg server
      minion = Pvcglue.cloud.minions_filtered('pg').values.first
      minion && minion.private_ip
    end

    def self.memcached_host
      # Assume first server
      minion = Pvcglue.cloud.minions_filtered('memcached').values.first
      ip = minion && minion.private_ip
      ip ? "#{ip}:11211" : nil
    end

    def self.redis_url
      # Assume first server
      # TODO:  (low priority) check all other apps/environments to see if
      # the current database number is used, and find an unused one, if it is.
      minion = Pvcglue.cloud.minions_filtered('redis').values.first
      ip = minion && minion.private_ip
      ip ? "redis://#{ip}:6379/0" : nil
    end

    def self.new_password
      "a#{SecureRandom.hex(16)}"
    end

    def self.write_stage_env_cache
      File.write(stage_env_cache_file_name, TOML.dump(Pvcglue.cloud.stage_env))
    end

    def self.read_cached_stage_env
      # TODO:  Only use cache in development of gem, do not cache by default, use Manager config
      return false # disable cache for now

      if File.exists?(stage_env_cache_file_name)
        stage_env = File.read(stage_env_cache_file_name)
        Pvcglue.cloud.stage_env = TOML.parse(stage_env)
        return true
      end
      false
    end

    def self.stage_env_file_name
      File.join(Pvcglue::Manager.manager_dir, stage_env_file_name_base)
    end

    def self.stage_env_file_name_base
      @stage_env_file_name_base ||= "#{Pvcglue.configuration.cloud_name}_#{Pvcglue.configuration.application_name}_#{Pvcglue.cloud.stage_name_validated}.env.toml"
    end

    def self.stage_env_cache_file_name
      File.join(Pvcglue.configuration.pvcglue_tmp_dir, "pvcglue_cache_#{stage_env_file_name_base}")
    end

    def self.clear_stage_env_cache
      File.delete(stage_env_cache_file_name) if File.exists?(stage_env_cache_file_name)
    end

    def self.apply_changes
      Pvcglue.cloud.minions.each do |minion_name, minion|
        if minion.has_roles? %w(web worker)
          Pvcglue::Packages::Secrets.apply(minion)
        end
      end
    end
  end

end
