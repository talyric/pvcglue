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
  end
end

package 'postgresql-root-password' do
  apply do
    # TODO: Use this to implement setting of the root password
    # sudo(%q[sudo -u postgres psql -c "ALTER ROLE postgres WITH PASSWORD 'zzz';"])
  end
end

