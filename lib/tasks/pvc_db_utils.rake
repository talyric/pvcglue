namespace :db do
  desc "Rebuild (drop, create, migrate) db. Then restore (or seed) and clone the test db.  Will restore db/rebuild.sql by default.  Use `rake db:rebuild[filename]` to restore db/filename.sql. Use `rake db:rebuild[-seed]` to instead load seed data."
  task :rebuild, [:filename] do |t, args|
    raise "This task can not be run in this environment.  (Hint:  Use 'db:reload' for heroku.)" unless %w[development].include? Rails.env
    db = Rails.configuration.database_configuration[Rails.env]
    puts "DB=#{db["database"]}"
    # if something fails and you are unable to access the db, you can drop it with the following:
    # /usr/bin/dropdb 'store-dev'
    # /usr/bin/dropdb 'store-test'
    # modified from http://stackoverflow.com/a/5408501/444774

    puts "Forcibly disconnecting other processes from database...(You may need to restart them.)"

    require 'active_record/connection_adapters/postgresql_adapter'
    module ActiveRecord
      module ConnectionAdapters
        class PostgreSQLAdapter < AbstractAdapter
          def drop_database(name)
            raise "Nah, I won't drop the production database" if Rails.env.production?
            begin
              psql_version_num = execute "select setting from pg_settings where name = 'server_version_num'"
              if psql_version_num.values.first.first.to_i < 90200
                #puts "version < 9.2"
                psql_version_pid_name = 'procpid'
              else
                #puts "version >= 9.2"
                psql_version_pid_name = 'pid'
              end

              execute <<-SQL
                UPDATE pg_catalog.pg_database
                SET datallowconn=false WHERE datname='#{name}'
              SQL

              execute <<-SQL
                SELECT pg_terminate_backend(pg_stat_activity.#{psql_version_pid_name})
                FROM pg_stat_activity
                WHERE pg_stat_activity.datname = '#{name}';
              SQL

              execute "DROP DATABASE IF EXISTS #{quote_table_name(name)}"
            ensure
              execute <<-SQL
                UPDATE pg_catalog.pg_database
                SET datallowconn=true WHERE datname='#{name}'
              SQL
            end
          end
        end
      end
    end
    puts "Dropping the db..."
    Rake::Task['db:drop'].invoke
    puts "Creating the db..."
    Rake::Task['db:create'].invoke

    if args.filename == "-seed"
      puts "Migrating the db..."
      Rake::Task['db:migrate'].invoke
      puts "Seeding the db..."
      Rake::Task['db:seed'].invoke
    else
      args.with_defaults(:filename => "rebuild")
      puts "Restoring dump: #{args.filename}..."
      Rake::Task['db:restore'].invoke(args.filename)
    end

    puts "Cloning the test db..."
    Rake::Task['db:test:prepare'].invoke
    puts "Done with DB=#{db["database"]}"
  end

  desc "Reload schema, then seed. (Does not try to drop and recreate db, which causes problems on heroku.)"
  task :reload, [:filename] => :environment do |t, args|
    raise "This task can not be run in this environment." unless %w[development alpha beta preview].include? Rails.env
    puts "Dropping/loading the db..."
    Rake::Task['db:schema:load'].invoke
    if args.filename == "seed!"
      puts "Seeding the db..."
      Rake::Task['db:seed'].invoke
    else
      args.with_defaults(:filename => "rebuild")
      puts "Restoring dump: #{args.filename}..."
      Rake::Task['db:restore'].invoke(args.filename)
    end
    puts "Done."
  end

  desc 'dump database (without schema_migrations) to *.sql using pg_dump. Ex: `rake db:backup[filename]` (filename is optional, default = "rebuild").  Use `rake db:backup[rebuild]` to use dump as default for `rake db:rebuild`.'
  task :backup_data_only, :filename do |t, args|
    db = Rails.configuration.database_configuration[Rails.env]
    #cmd = "pg_dump -Fc --no-acl --no-owner -h #{db["host"]} -p #{db["port"]} -U #{db["username"]} #{db["database"]} > #{Rails.root}/db/#{args[:filename]}.dump"
    cmd = "pg_dump -Fp --column-inserts --no-acl --no-owner --data-only -h #{db["host"]} -p #{db["port"]}"
    cmd += " -U #{db["username"]}" unless db["username"].blank?
    #cmd += " --exclude-table=schema_migrations"
    cmd += " --exclude-table=cacheinators -T cacheinators_id_seq"
    cmd += " #{db["database"]} > #{path_with_default(args[:filename])}"
    puts cmd
    unless system({"PGPASSWORD" => db["password"]}, cmd)
      puts "ERROR:"
      puts $?.inspect
    end
  end

  desc 'dump database (with schema) to *.sql using pg_dump. Ex: `rake db:backup[filename]` (filename is optional, default = "rebuild").  Use `rake db:backup[rebuild]` to use dump as default for `rake db:rebuild`.'
  task :backup, :filename do |t, args|
    db = Rails.configuration.database_configuration[Rails.env]
    #cmd = "pg_dump -Fp --column-inserts --no-acl --no-owner --clean -h #{db["host"]} -p #{db["port"]}"
    cmd = "pg_dump -Fp --column-inserts --no-acl --no-owner -h #{db["host"]} -p #{db["port"]}"
    cmd += " -U #{db["username"]}" unless db["username"].blank?
    #cmd += " --exclude-table=cacheinators -T cacheinators_id_seq"
    cmd += " #{db["database"]} > #{path_with_default(args[:filename])}"
    puts cmd
    unless system({"PGPASSWORD" => db["password"]}, cmd)
      puts "ERROR:"
      puts $?.inspect
    end
  end

  #task :restore_zzz, :filename do |t, args|
  #  desc 'restore database from sql file. Ex: `rake db:backup[filename]` (filename is optional, default = "dump").'
  #  args.with_defaults(:filename => 'dump')
  #  db = Rails.configuration.database_configuration[Rails.env]
  #  ap db
  #  #cmd = "pg_restore --verbose --clean --no-acl --no-owner -h #{db["host"]} -p #{db["port"]} -U #{db["username"]} -d #{db["database"]} #{Rails.root}/db/#{args[:filename]}.dump"
  #  cmd = "psql -h #{db["host"]} -p #{db["port"]} -U #{db["username"]} -d #{db["database"]} -f #{Rails.root}/db/#{args[:filename]}.sql"
  #  puts cmd
  #  raise "Does not compute...destroying the production database is illogical.  If you are *REALLY* sure, use the command above." if Rails.env.production?
  #  if system({"PGPASSWORD" => db["password"]}, cmd)
  #    puts
  #    puts "*"*80
  #    puts "Don't forget to restart the Rails server!"
  #    puts "*"*80
  #    puts
  #  else
  #    fail "ERROR:  "+$?.inspect
  #  end
  #end

  desc 'restore database from sql file. Ex: `rake db:backup[filename]` (filename is optional, default = "rebuild").'
  task :restore, [:filename] => :environment do |t, args|
    raise "Does not compute...destroying the production database is illogical." if Rails.env.production? && !destroy_prod?
    begin
      #ActiveRecord::Base.connection.execute("DELETE FROM schema_migrations;\n#{File.open(path_with_default(args[:filename])).read}")
      ActiveRecord::Base.connection.execute("#{filter_sql(File.open(path_with_default(args[:filename])).read)}")
    rescue ActiveRecord::StatementInvalid => e
      puts "\n\n\n** DATABASE ERROR *************************************************************"
      puts e.message.truncate(1000)
      raise "*"*80+"\nDB Reload Error :(\n"+"*"*80
    end
  end

  desc 'restore database from sql file. Ex: `rake db:backup[filename]` (filename is optional, default = "dump").'
  task :info, [:filename] => :environment do |t, args|
    db = Rails.configuration.database_configuration[Rails.env]
    ap db
  end


  def path_with_default(basename)
    basename = 'rebuild' if basename.blank?
    basename = File.basename(basename, '.*') # remove everything except basename
    if basename == 'rebuild' && File.exist?(basename_to_path("#{basename}-#{Rails.env}"))
      return basename_to_path("#{basename}-#{Rails.env}")
    end
    basename_to_path(basename)
  end

  def basename_to_path(basename)
    "#{Rails.root}/db/#{basename}.sql"
  end


  def destroy_prod?
    puts "Are you *REALLY* sure you want to DESTROY the PRODUCTION database?"
    puts "Type 'destroy production' if you are."
    STDOUT.flush
    input = STDIN.gets.chomp
    if input.downcase == "destroy production"
      puts "ok, going through with the it..."
      return true
    else
      raise "Ain't gonna do it."
    end
  end

  def filter_sql(sql)
    raise "Nope..." if Rails.env.production?
    sql = "DROP SCHEMA IF EXISTS public CASCADE;\nCREATE SCHEMA public;\n" + sql
    sql.gsub!("CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;", '')
    sql.gsub!("COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';", '')
    #sql.gsub!(/(DROP) (INDEX|SEQUENCE|TABLE|SCHEMA|EXTENSION|CONSTRAINT) (.*);$/,'\1 \2 IF EXISTS \3;')
    #sql.gsub(/(DROP|ALTER) (INDEX|SEQUENCE|TABLE|SCHEMA|EXTENSION|CONSTRAINT) (.*);$/,'\1 \2 IF EXISTS \3;')
    sql
  end
end

=begin

DROP INDEX public.unique_schema_migrations;
ALTER TABLE ONLY public.vendors DROP CONSTRAINT vendors_pkey;
ALTER TABLE public.vendors ALTER COLUMN id DROP DEFAULT;
DROP SEQUENCE public.adjusters_id_seq;
DROP TABLE public.adjusters;
DROP EXTENSION plpgsql;
DROP SCHEMA public;
--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--
=end
