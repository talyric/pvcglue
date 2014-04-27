#=======================================================================================================================
package 'db' do
#=======================================================================================================================
  depends_on 'postgresql'
  depends_on 'postgresql-remote'
  depends_on 'postgresql-app-db'
  app_env({command: :manage})
end

package 'postgresql-remote' do
  file({
           :source => 'files/postgresql.conf',
           :destination => '/etc/postgresql/9.1/main/postgresql.conf',
           :create_dirs => false,
           :permissions => 0644,
           :user => 'postgres',
           :group => 'postgres'
       }) { trigger 'postgresql:restart' }

  file({
           :source => 'files/pg_hba.conf',
           :destination => '/etc/postgresql/9.1/main/pg_hba.conf',
           :create_dirs => false,
           :permissions => 0644,
           :user => 'postgres',
           :group => 'postgres'
       }) { trigger 'postgresql:restart' }
  apply do
    #TODO:  This password should not be hard-coded here!  It may not be necessary to set it at all...we'll have to see later.
    sudo(%q[sudo -u postgres psql -c "ALTER ROLE postgres WITH PASSWORD '3veQdGzeN2';"])
  end
end

package 'postgresql-app-db' do
  apply do
    # Save application and stage specific db password to the db server
    # This maybe should be done as 'root'...not sure.  Or maybe create a table in the db for this info.  ;)
    raise 'missing options' if ENV['PVC_APP_NAME'].blank? || ENV['PVC_STAGE'].blank?
    username = "#{ENV['PVC_APP_NAME']}_#{ENV['PVC_STAGE']}".downcase
    db_name = username # just for clarity in later statements.  This also must match database.yml.
    file_dir = "/root/.pvc"
    filename = "#{file_dir}/#{username}.password"
    sudo("mkdir -p #{file_dir}")
    sudo("touch #{filename}")
    password = sudo("cat #{filename}").strip
    if password.blank?
      password = "#{db_name}_#{SecureRandom.hex(4)}"
      sudo(%Q[echo '#{password}' | sudo tee #{filename}])
      sudo(%Q[chmod 600 #{filename}])
    end
    ENV['PVC_DB_PASSWORD'] = password
    puts ("|"*80)+"password"
    run(%Q[sudo -u postgres psql -c "CREATE ROLE #{username} LOGIN CREATEDB PASSWORD '#{password}'"])
    run(%Q[sudo -u postgres psql -c "ALTER ROLE #{username} PASSWORD '#{password}' CREATEDB LOGIN"])
    run(%Q[sudo -u postgres psql -c "CREATE DATABASE #{db_name} WITH OWNER #{username}"])
  end
end


