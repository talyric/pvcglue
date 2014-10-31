module Pvcglue
  class Db < Thor

    desc "config", "create/update database.yml"

    def config
      Pvcglue::Db.configure_database_yml
    end

    desc "push", "push"

    def push(file_name = nil)
      raise(Thor::Error, "Stage required.") if Pvcglue.cloud.stage_name.nil?
      pg_restore(self.class.remote, file_name)
    end

    desc "pull", "pull"
    method_option :fast, :type => :boolean, :aliases => "-f"
    def pull(file_name = nil)
      raise(Thor::Error, "Stage required.") if Pvcglue.cloud.stage_name.nil?
      pg_dump(self.class.remote, file_name, options[:fast])
    end

    desc "dump", "dump"

    def dump(file_name = nil)
      raise(Thor::Error, "Stage should not be set for this command.") unless Pvcglue.cloud.stage_name.nil?
      pg_dump(self.class.local, file_name)
    end

    desc "restore", "restore"

    def restore(file_name = nil)
      raise(Thor::Error, "Stage should not be set for this command.") unless Pvcglue.cloud.stage_name.nil?
      pg_restore(self.class.local, file_name)
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

    def self.configure_database_yml
      Pvcglue.render_template('database.yml.erb', Pvcglue::Db.database_yml_file_name)
    end


    # ------------------------------------------------------------------------------------------------------------------

    # silence Thor warnings, as these are not Thor commands.  (But we still need 'say' and 'ask' and friends.)
    no_commands do

      def destroy_prod?
        say("Are you *REALLY* sure you want to DESTROY the PRODUCTION database?")
        input = ask("Type 'destroy production' if you are:")
        raise(Thor::Error, "Ain't gonna do it.") if input.downcase != "destroy production"
        puts "ok, going through with the it..."
      end


      def pg_dump(source, file_name, fast)
        cmd = "pg_dump -Fc --no-acl --no-owner -h #{source.host} -p #{source.port}"
        cmd += " -U #{source.username}" if source.username
        if fast
          Pvcglue.cloud.exclude_tables.each do |table|
            cmd += " --exclude-table=#{table}"
          end
        end
        cmd += " #{source.database} -v -f #{self.class.file_helper(file_name)}"
        puts cmd
        unless system({"PGPASSWORD" => source.password}, cmd)
          puts "ERROR:"
          puts $?.inspect
        end
      end

      def pg_restore(dest, file_name)
        Pvcglue.cloud.stage_name == 'production' && destroy_prod?
        cmd = "pg_restore --verbose --clean --no-acl --no-owner -h #{dest.host} -p #{dest.port}"
        cmd += " -U #{dest.username}" if dest.username
        cmd += " -d #{dest.database} #{self.class.file_helper(file_name)}"
        puts cmd
        unless system({"PGPASSWORD" => dest.password}, cmd)
          puts "ERROR:"
          puts $?.inspect
        end
      end
    end

  end

end
