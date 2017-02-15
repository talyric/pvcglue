require 'yaml'
module Pvcglue
  class Db < Thor

    desc "config", "create/update database.yml"

    def config
      Pvcglue::Db.configure_database_yml
    end

    desc "push", "push"

    def push(file_name = nil)
      raise(Thor::Error, "Stage required.") if Pvcglue.cloud.stage_name.nil?
      pg_restore(self.class.remote, file_name, options[:fast])
    end

    desc "pull", "Pull copy of database from remote stage.  Pass -f to exclude tables defined in the configuration file.  If no tables are specified in the `excluded_db_tables` option, 'versions' will be used by default."
    method_option :fast, :type => :boolean, :aliases => "-f"

    def pull(file_name = nil)
      raise(Thor::Error, "Stage required.") if Pvcglue.cloud.stage_name.nil?
      pg_dump(self.class.remote, file_name, options[:fast])
    end

    desc "dump", "dump"

    def dump(file_name = nil)
      raise(Thor::Error, "Stage should not be set for this command.  (Use 'pull' for remote databases.)") unless Pvcglue.cloud.stage_name.nil?
      pg_dump(self.class.local, file_name, options[:fast])
    end

    desc "restore", "restore"

    def restore(file_name = nil)
      raise(Thor::Error, "Stage should not be set for this command.  (Use 'push' for remote databases.)") unless Pvcglue.cloud.stage_name.nil?
      pg_restore(self.class.local, file_name)
    end

    desc "destroy_all", "destroy_all"

    def destroy_all
      raise(Thor::Error, "Stage should not be set for this command.") unless Pvcglue.cloud.stage_name.nil?
      pg_destroy(self.class.local)
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

    class Db_Config < Struct.new(:host, :port, :database, :username, :password, :kind)
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
        Db_Config.new(dev["host"], dev["port"], dev["database"], dev["username"], dev["password"], :local)
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
                      env["DB_USER_POSTGRES_PASSWORD"],
                      :remote
        )
      end
    end

    def self.db_host_public
      node = Pvcglue.cloud.find_minion_by_name('db')
      node['db']['public_ip']
    end


    def self.file_helper(file_name)
      # TODO:  make it more helpful ;)
      stage = Pvcglue.cloud.stage_name || "dev"
      file_name = "#{Pvcglue.configuration.application_name}_#{stage}_#{Time.now.strftime("%Y-%m-%d-%H%M")}.dump" unless file_name
      # "#{File.dirname(file_name)}/#{File.basename(file_name, '.*')}.dump"
      file_name
    end

    def self.configure_database_yml
      Pvcglue.render_template('database.yml.erb', Pvcglue::Db.database_yml_file_name)
    end


    # ------------------------------------------------------------------------------------------------------------------

    # silence Thor warnings, as these are not Thor commands.  (But we still need 'say' and 'ask' and friends.)
    no_commands do

      def destroy_prod?(db)
        say("Are you *REALLY* sure you want to DESTROY the PRODUCTION database?")
        input = ask("Type 'destroy #{db.database.downcase}' if you are:")
        raise(Thor::Error, "Ain't gonna do it.") if input.downcase != "destroy #{db.database.downcase}"
        puts "ok, going through with the it...  (I sure hope you know what you are doing, Keith!)"
      end


      def pg_dump(db, file_name, fast)
        file_name = self.class.file_helper(file_name)

        if db.kind == :remote
          host = Pvcglue.cloud.minions_filtered('db')['db']['public_ip']
          port = Pvcglue.cloud.port_in_context(:shell)
          user = 'deploy'
        end

        cmd = "pg_dump -Fc --no-acl --no-owner -h #{db.host} -p #{db.port}"
        cmd += " -U #{db.username}" if db.username
        if fast
          Pvcglue.cloud.exclude_tables.each do |table|
            cmd += " --exclude-table=#{table}"
          end
        end
        cmd += " #{db.database} -v -f #{file_name}"

        puts cmd

        cmd = " PGPASSWORD=#{db.password} #{cmd}"

        if db.kind == :remote
          unless Pvcglue.run_remote(host, port, user, cmd)
            puts "ERROR:"
            puts $?.inspect
            raise(Thor::Error, "Error:  #{$?}")
          end

          cmd = %{scp -P #{port} #{user}@#{host}:#{file_name} #{file_name}}
          puts "Running `#{cmd}`"

          unless system cmd
            raise(Thor::Error, "Error:  #{$?}")
          end
        else
          unless system(cmd)
            puts "ERROR:"
            puts $?.inspect
            raise(Thor::Error, "Error:  #{$?}")
          end
        end
      end

      def pg_restore(db, file_name, fast = false)
        Pvcglue.cloud.stage_name == 'production' && destroy_prod?(db)
        file_name = self.class.file_helper(file_name)

        if db.kind == :remote
          host = Pvcglue.cloud.minions_filtered('db')['db']['public_ip']
          port = Pvcglue.cloud.port_in_context(:shell)
          user = 'deploy'

          # cmd = %{scp -P #{port} #{file_name} #{user}@#{host}:#{file_name}}
          cmd = %{rsync -avhPe "ssh -p #{port}" --progress #{file_name} #{user}@#{host}:#{file_name}}
          unless system cmd
            raise(Thor::Error, "Error:  #{$?}")
          end

          unless fast
            # Drop and recreate DB
            Pvcglue::Packages.apply('postgresql-app-stage-db-drop'.to_sym, :build, Pvcglue.cloud.minions_filtered('db'))
            Pvcglue::Packages.apply('postgresql-app-stage-conf'.to_sym, :build, Pvcglue.cloud.minions_filtered('db'))
          end
        end

        cmd = "pg_restore --verbose --clean --no-acl --no-owner -h #{db.host} -p #{db.port}"
        cmd += " -U #{db.username}" if db.username
        cmd += " -d #{db.database} #{file_name}"
        puts cmd

        if db.kind == :remote
          unless Pvcglue.run_remote(host, port, user, " PGPASSWORD=#{db.password} #{cmd}")
            puts "ERROR:"
            puts $?.inspect
          end
        else
          unless system(" PGPASSWORD=#{db.password} #{cmd}")
            raise(Thor::Error, "Error:  #{$?}")
          end
        end

      end

      def pg_destroy(dest)
        sql = "\"select 'drop database '||datname||';' "\
               "from pg_database "\
               "where datistemplate=false and datname <> '#{dest.username}' "\
               "and datname <> 'postgres'\""
        # I had to use the double for loop because for whatever reason
        # calling ${line[0]} throws a bad substitution error
        # This is also why I escaped the string with a regex
        bash = "#!/bin/bash\n while read line; do "\
                  "s_esc=\"$(echo \"$line\" | sed 's/[^-A-Za-z0-9_]/\\ /g')\"; "\
                  "for word in $s_esc; do "\
                    "if [ $word = \"drop\" ]; then "\
                      "for word in $s_esc; do "\
                        "if [ $word != \"drop\" ] && [ $word != \"database\" ]; then "\
                          "echo \"$s_esc\"; "\
                          "dropdb \"$word\"\; "\
                        "fi "\
                      "done; "\
                      "break; "\
                    "fi "\
                  "done; "\
               "done < dd.sql; "

        cmd = "psql #{dest.username} -c "
        cmd += sql
        cmd += " > dd.sql;"
        cmd += bash
        cmd += "rm dd.sql"
        puts cmd
        unless system({"PGPASSWORD" => dest.password}, cmd)
          puts "ERROR:"
          puts $?.inspect
        end
      end

    end

  end

end
