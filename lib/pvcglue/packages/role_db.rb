package 'db' do
  depends_on 'env-initialized'
  depends_on 'postgresql'
  depends_on 'postgresql-conf'
  depends_on 'postgresql-app-stage-conf'
end

package 'postgresql-conf' do
  file({
           :template => Pvcglue.template_file_name('postgresql.conf.erb'),
           :destination => '/etc/postgresql/9.1/main/postgresql.conf',
           :create_dirs => false,
           :permissions => 0644,
           :user => 'postgres',
           :group => 'postgres'
       }) { trigger 'postgresql:restart' }

  file({
           :template => Pvcglue.template_file_name('pg_hba.conf.erb'),
           :destination => '/etc/postgresql/9.1/main/pg_hba.conf',
           :create_dirs => false,
           :permissions => 0644,
           :user => 'postgres',
           :group => 'postgres'
       }) { trigger 'postgresql:restart' }
end

package 'postgresql-app-stage-conf' do
  # TODO: Add `verify` method so it will be faster, and won't display errors
  apply do
    username = Pvcglue.cloud.stage_env['DB_USER_POSTGRES_USERNAME']
    password = Pvcglue.cloud.stage_env['DB_USER_POSTGRES_PASSWORD']
    db_name = username # just for clarity in later statements.  This also must match database.yml.
    run(%Q[sudo -u postgres psql -c "CREATE ROLE #{username} LOGIN CREATEDB PASSWORD '#{password}'"])
    run(%Q[sudo -u postgres psql -c "ALTER ROLE #{username} PASSWORD '#{password}' CREATEDB LOGIN"])
    run(%Q[sudo -u postgres psql -c "CREATE DATABASE #{db_name} WITH OWNER #{username}"])
    run(%Q[sudo -u postgres psql #{db_name} -c "ALTER SCHEMA public OWNER TO #{username}"])
  end
end

package 'postgresql-app-stage-db-drop' do
  apply do
    username = Pvcglue.cloud.stage_env['DB_USER_POSTGRES_USERNAME']
    db_name = username # just for clarity in later statements.  This also must match database.yml.

    sql = <<-SQL
                UPDATE pg_catalog.pg_database
                SET datallowconn=false WHERE datname='#{db_name}'
    SQL
    run(%Q[sudo -u postgres psql -c "#{sql}"])

    # To simplify logic, try it with both versions.
    # version >= 9.2
    sql = <<-SQL
                SELECT pg_terminate_backend(pg_stat_activity.pid)
                FROM pg_stat_activity
                WHERE pg_stat_activity.datname = '#{db_name}';
    SQL
    run(%Q[sudo -u postgres psql -c "#{sql}"])

    # #puts "version < 9.2"
    sql = <<-SQL
                SELECT pg_terminate_backend(pg_stat_activity.procpid)
                FROM pg_stat_activity
                WHERE pg_stat_activity.datname = '#{db_name}';
    SQL
    run(%Q[sudo -u postgres psql -c "#{sql}"])

    run(%Q[sudo -u postgres psql -c "DROP DATABASE #{db_name}"])

    sql = <<-SQL
                UPDATE pg_catalog.pg_database
                SET datallowconn=true WHERE datname='#{db_name}'
    SQL
    run(%Q[sudo -u postgres psql -c "#{sql}"])

  end
end

package 'postgresql-root-password' do
  apply do
    # TODO: Use this to implement setting of the root password
    # sudo(%q[sudo -u postgres psql -c "ALTER ROLE postgres WITH PASSWORD 'zzz';"])
  end
end

