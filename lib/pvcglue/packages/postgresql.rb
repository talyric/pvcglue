module Pvcglue
  class Packages
    class Postgresql < Pvcglue::Packages

      def installed?
        get_minion_state(:postgresql_updated_at)
      end

      def install!
        Pvcglue::Env.initialize_stage_env
        connection.write_to_file_from_template(:root, 'postgresql.conf.erb', '/etc/postgresql/9.6/main/postgresql.conf', 'postgres', 'postgres', '0644')
        connection.write_to_file_from_template(:root, 'pg_hba.conf.erb', '/etc/postgresql/9.6/main/pg_hba.conf', 'postgres', 'postgres', '0644')

        connection.run_get_stdout(:root, '', 'service postgresql restart')
        unless $?.exitstatus == 0
          Pvcglue.logger.error { 'Unable to (re)start postgresql.  Getting status...' }
          result = connection.run_get_stdout(:root, '', 'systemctl status postgresql.service')
          puts result
          raise('There was a problem restarting PostgreSQL.')
        end

        username = Pvcglue.cloud.stage_env['DB_USER_POSTGRES_USERNAME']
        password = Pvcglue.cloud.stage_env['DB_USER_POSTGRES_PASSWORD']
        db_name = username # just for clarity in later statements.  This also must match database.yml.
        connection.ssh!(:root, '', %Q[sudo -u postgres psql -c "CREATE ROLE #{username} LOGIN CREATEDB PASSWORD \\'#{password}\\'"])
        connection.ssh!(:root, '', %Q[sudo -u postgres psql -c "ALTER ROLE #{username} PASSWORD \\'#{password}\\' CREATEDB LOGIN"])
        connection.ssh!(:root, '', %Q[sudo -u postgres psql -c "CREATE DATABASE #{db_name} WITH OWNER #{username}"])
        connection.ssh!(:root, '', %Q[sudo -u postgres psql #{db_name} -c "ALTER SCHEMA public OWNER TO #{username}"])


        set_minion_state(:postgresql_updated_at, Time.now.utc)
      end

    end

  end
end
