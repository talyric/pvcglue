module Pvcglue
  class Db < Thor

    desc "config", "create/update database.yml"

    def config
      Pvcglue.render_template('database.yml.erb', Pvcglue::Db.database_yml_file_name)
    end

    desc "push", "push"

    def push(file_name = nil)
      raise(Thor::Error, "Stage required.") if Pvcglue.cloud.stage_name.nil?

    end

    desc "pull", "pull"

    def pull(file_name = nil)
      raise(Thor::Error, "Stage required.") if Pvcglue.cloud.stage_name.nil?
      self.class.dump(self.class.remote, file_name)
    end

    desc "dump", "dump"

    def dump(file_name = nil)
      raise(Thor::Error, "Stage should not be set for this command.") unless Pvcglue.cloud.stage_name.nil?
      self.class.dump(self.class.local, file_name)
    end

    desc "restore", "restore"

    def restore(file_name = nil)
      raise(Thor::Error, "Stage should not be set for this command.") unless Pvcglue.cloud.stage_name.nil?

    end

    desc "info", "info"

    def info
      if Pvcglue.cloud.stage_name
        pp self.class.remote
      else
        pp self.class.local
      end
    end

    # ------------------------------------------------------------------------------------------------------------------

    def self.database_yml_file_name
      File.join(Pvcglue::Capistrano.application_config_dir, 'database.yml')
    end

    class Db_Config < Struct.new(:host, :port, :database, :username, :password)
    end

    def self.local_info
      @local_info ||= begin
        template = Tilt::ERBTemplate.new('config/database.yml')
        output = template.render
        # puts output.inspect
        info = YAML::load(output)
        # puts info.inspect
        info
      end
    end

    def self.local
      @local ||= begin
        dev = local_info["development"]
        Db_Config.new(dev["host"], dev["port"], dev["database"], dev["username"], dev["password"])
      end
    end

    def self.remote
      @remote ||= begin
        Pvcglue::Env.initialize_stage_env
        env = Pvcglue.cloud.stage_env
        Db_Config.new(db_host_public,
                      env["DB_USER_POSTGRES_PORT"],
                      env["DB_USER_POSTGRES_DATABASE"],
                      env["DB_USER_POSTGRES_USERNAME"],
                      env["DB_USER_POSTGRES_PASSWORD"])
      end
    end

    def self.db_host_public
      node = Pvcglue.cloud.find_node('db')
      node['db']['public_ip']
    end


    def self.file_helper(file_name)
      # TODO:  make it more helpful ;)
      stage = Pvcglue.cloud.stage_name || "dev"
      file_name = "#{Pvcglue.configuration.application_name}_#{stage}_#{Time.now.strftime("%Y-%m-%d")}.dump" unless file_name
      # "#{File.dirname(file_name)}/#{File.basename(file_name, '.*')}.dump"
      file_name
    end

    def self.dump(source, file_name)
      cmd = "pg_dump -Fc --no-acl --no-owner -h #{source.host} -p #{source.port}"
      cmd += " -U #{source.username}" if source.username
      cmd += " #{source.database} -v -f #{file_helper(file_name)}"
      puts cmd
      unless system({"PGPASSWORD" => source.password}, cmd)
        puts "ERROR:"
        puts $?.inspect
      end
    end
  end

end
