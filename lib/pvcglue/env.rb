require 'pp'

module Pvcglue
  class Env < Thor

    desc "push", "push"

    def push
      Pvcglue::Packages.apply('env-push'.to_sym, :manager, Pvcglue::Manager.manager_node, 'pvcglue')
      self.class.clear_stage_env_cache
      Pvcglue::Packages.apply('app-env-file'.to_sym, :env, Pvcglue.cloud.nodes_in_stage('web'))
    end

    desc "pull", "pull"

    def pull
      Pvcglue::Packages.apply('env-pull'.to_sym, :manager, Pvcglue::Manager.manager_node, 'pvcglue')
      self.class.clear_stage_env_cache
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
      options = Hash[args.each.map { |l| l.chomp.split('=') }]
      Pvcglue.cloud.stage_env.merge!(options)
      self.class.save_stage_env
      Pvcglue::Packages.apply('app-env-file'.to_sym, :env, Pvcglue.cloud.nodes_in_stage('web'))
    end

    desc "unset", "remove environment variable(s) for the stage XYZ [ZZZ]"

    def unset(*args)
      self.class.initialize_stage_env
      args.each { |arg| puts "WARNING:  Key '#{arg}' not found." unless Pvcglue.cloud.stage_env.delete(arg) }
      self.class.save_stage_env
      Pvcglue::Packages.apply('app-env-file'.to_sym, :env, Pvcglue.cloud.nodes_in_stage('web'))
    end

    desc "rm", "alternative to unset"

    def rm(*args)
      unset(*args)
    end


    # ------------------------------------------------------------------------------------------------------------------

    def self.initialize_stage_env
      unless read_cached_stage_env
        Pvcglue::Packages.apply('env-get-stage'.to_sym, :manager, Pvcglue::Manager.manager_node, 'pvcglue')
        write_stage_env_cache
      end
      merged = stage_env_defaults.merge(Pvcglue.cloud.stage_env)
      if merged != Pvcglue.cloud.stage_env
        Pvcglue.cloud.stage_env = merged
        save_stage_env
      end
    end

    def self.save_stage_env
      Pvcglue::Packages.apply('env-set-stage'.to_sym, :manager, Pvcglue::Manager.manager_node, 'pvcglue')
      write_stage_env_cache
    end

    def self.stage_env_defaults
      {
          'RAILS_SECRET_TOKEN' => SecureRandom.hex(64),
          'DB_USER_POSTGRES_HOST' => db_host,
          'DB_USER_POSTGRES_PORT' => "5432",
          'DB_USER_POSTGRES_USERNAME' => "#{Pvcglue.cloud.app_name}_#{Pvcglue.cloud.stage_name_validated}",
          'DB_USER_POSTGRES_DATABASE' => "#{Pvcglue.cloud.app_name}_#{Pvcglue.cloud.stage_name_validated}",
          'DB_USER_POSTGRES_PASSWORD' => new_password,
          'MEMCACHE_SERVERS' => memcached_host,
          'REDIS_SERVER' => redis_host
      }
    end

    def self.db_host
      node = Pvcglue.cloud.find_node('db')
      node['db']['private_ip']
    end

    def self.memcached_host
      node = Pvcglue.cloud.find_node('memcached', false)
      node ? "#{node['memcached']['private_ip']}:11211" : ""
    end

    def self.redis_host
      node = Pvcglue.cloud.find_node('redis', false)
      node ? "#{node['redis']['private_ip']}:6379" : ""
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
      File.join(Pvcglue::Manager.manager_dir, stage_env_file_name_base)
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
