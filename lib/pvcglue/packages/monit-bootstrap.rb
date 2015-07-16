# check process delayed_job.0
#   with pidfile /sites/pvcglue_dev_box/local/shared/pids/delayed_job.0.pid
#   start program = "/home/deploy/.rvm/bin/rvm-shell -c 'cd /sites/pvcglue_dev_box/local/current && RAILS_ENV=local /sites/pvcglue_dev_box/local/current/bin/delayed_job start -i 0 --pid-dir=/sites/pvcglue_dev_box/local/shared/pids/'" as uid deploy and gid deploy
#   stop program = "/home/deploy/.rvm/bin/rvm-shell -c 'cd /sites/pvcglue_dev_box/local/current && RAILS_ENV=local /sites/pvcglue_dev_box/local/current/bin/delayed_job stop -i 0 --pid-dir=/sites/pvcglue_dev_box/local/shared/pids/'" as uid deploy and gid deploy
#   group delayed
#   depends on deploy_in_progress
#
# check file deploy_in_progress with path /sites/pvcglue_dev_box/local/shared/pids/deploying
#   if does not exist then exec "/bin/echo Does not exist" else if succeeded then exec "/bin/echo Exists"
# #  group delayed
# #  if changed timestamp then exec "/bin/echo"
#
# check process monit
#   with pidfile /var/run/monit.pid
#   restart program = "/usr/bin/monit reload"

# curl http://localhost:2812/monit -d "action=restart"

# curl http://localhost:2812/deploy_in_progress -d "action=start"

# For development
#
#  Stop the service:
#    sudo service monit stop
#
#  Run it manually:
#    sudo monit -Iv
#
#
package 'monit-bootstrap' do
  depends_on 'monit-install'
  depends_on 'monit-upstart'
end

package 'monit-install' do
  depends_on 'monit-config-files'

  validate do
    # next:  thanks to http://stackoverflow.com/questions/2325471/using-return-in-a-ruby-block
    next false unless run('monit -V') =~ /5\.14/
    next false unless sudo('monit -t') =~ /Control file syntax OK/
    sudo('monit status') =~ /status\s*Running/
  end

  apply do
    # Thanks to https://rtcamp.com/tutorials/monitoring/monit/
    sudo 'rm monit-5.14-linux-x64.tar.gz'
    sudo 'wget https://mmonit.com/monit/dist/binary/5.14/monit-5.14-linux-x64.tar.gz'
    sudo 'tar zxvf monit-5.14-linux-x64.tar.gz'
    sudo 'cp ~/monit-5.14/bin/monit /usr/bin/monit'
    sudo 'ln -s /etc/monit/monitrc /etc/monitrc'
    sudo 'mkdir -p /var/lib/monit/'
    sudo 'mkdir -p /etc/monit/conf.d/'
    sudo 'monit quit' # quit 'manually' and then start it as a service (or service monit stop, doesn't)
    sudo 'service monit start'
  end

  remove do
    raise "removing monit not supported, yet."
  end
end

package 'monit-config-files' do
  file({
           :template => Pvcglue.template_file_name('monit.init.d.erb'),
           :destination => '/etc/init.d/monit',
           :permissions => 0755,
           :user => 'root',
           :group => 'root'
       }) { sudo('service monit restart') }

  file({
           :template => Pvcglue.template_file_name('monit.monitrc.erb'),
           :destination => '/etc/monit/monitrc',
           :create_dirs => true,
           :permissions => 0700,
           :user => 'root',
           :group => 'root'
       }) { sudo('service monit restart') }

  file({
           :template => Pvcglue.template_file_name('monit.etc-default.erb'),
           :destination => '/etc/default/monit',
           :permissions => 0644,
           :user => 'root',
           :group => 'root'
       }) {}
end

package 'monit-upstart' do
  depends_on 'monit-upstart-files'

  validate do
    sudo('initctl status monit') =~ /monit start\/running/
  end

  apply do
    sudo 'service monit start'
  end

  remove do
    raise "removing monit not supported, yet."
  end
end

package 'monit-upstart-files' do
  file({
           :template => Pvcglue.template_file_name('monit.upstart-conf.erb'),
           :destination => '/etc/init/monit.conf',
           :permissions => 0644,
           :user => 'root',
           :group => 'root'
       }) { sudo 'initctl reload-configuration' }

end


