module Pvcglue
  class Db < Thor

    desc "config", "create/update database.yml"

    def config
      Pvcglue.render_template('database.yml.erb', Pvcglue::Db.database_yml_file_name)
    end

    desc "push", "push"

    def push(file_name)

    end

    desc "pull", "pull"

    def pull(file_name)

    end

    desc "dump", "dump"

    def dump(file_name)

    end

    desc "restore", "restore"

    def restore(file_name)

    end

    desc "info", "info"

    def info
      if Pvcglue.cloud.stage_name
        puts "not ready yet"
      else
        # require 'YAML'
        # info = YAML::load(IO.read("config/database.yml"))
        # puts info.inspect
        # require 'tilt/erb'
        template = Tilt::ERBTemplate.new('config/database.yml')
        output = template.render
        puts output.inspect
        info = YAML::load(output)
        puts info.inspect
      end
    end

    # ------------------------------------------------------------------------------------------------------------------

    def self.database_yml_file_name
      File.join(Pvcglue::Capistrano.application_config_dir, 'database.yml')
    end


    def self.stage_env_defaults
      {
          'RAILS_SECRET_TOKEN' => SecureRandom.hex(64),
          'DB_USER_POSTGRES_HOST' => db_host,
          'DB_USER_POSTGRES_PORT' => "5432",
          'DB_USER_POSTGRES_USERNAME' => "#{Pvcglue.cloud.app_name}_#{Pvcglue.cloud.stage_name_validated}",
          'DB_USER_POSTGRES_PASSWORD' => new_password,
          'MEMCACHE_SERVERS' => memcached_host
      }
    end

    def self.db_host
      node = Pvcglue.cloud.find_node('db')
      node['db']['private_ip']
    end

    def self.memcached_host
      node = Pvcglue.cloud.find_node('memcached')
      "#{node['memcached']['private_ip']}:11211"
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
