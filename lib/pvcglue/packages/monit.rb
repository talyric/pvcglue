package 'monit' do
  depends_on 'monit-install'
  depends_on 'monit-upstart'
end

package 'monit-install' do
  depends_on 'monit-config-files'

  validate do
    return false unless run('monit -V') =~ /5\.14/
    return false unless sudo('monit -t') =~ /Control file syntax OK/
    sudo('monit status') =~ /status\s*Running/
  end

  apply do
    # Thanks to https://rtcamp.com/tutorials/monitoring/monit/
    sudo 'rm monit-5.14-linux-x64.tar.gz'
    sudo 'wget https://mmonit.com/monit/dist/binary/5.14/monit-5.14-linux-x64.tar.gz'
    sudo 'tar zxvf monit-5.14-linux-x64.tar.gz'
    sudo 'cp ~/monit-5.14/bin/monit /usr/bin/monit'
    sudo 'ln -s /etc/monit/monitrc /etc/monitrc'
    sudo 'service monit restart'
  end

  remove do
    raise "removing monit not supported, yet."
  end
end

package 'monit-config-files' do
  file({
           :template => Pvcglue.template_file_name('monit_init.d.erb'),
           :destination => '/etc/init.d/monit',
           :permissions => 0755,
           :user => 'root',
           :group => 'root'
       }) { sudo('service monit restart') }

  file({
           :template => Pvcglue.template_file_name('monitrc.erb'),
           :destination => '/etc/monit/monitrc',
           :create_dirs => true,
           :permissions => 0700,
           :user => 'root',
           :group => 'root'
       }) { sudo('service monit restart') }

  file({
           :template => Pvcglue.template_file_name('monit_default.erb'),
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
           :template => Pvcglue.template_file_name('monit.conf.erb'),
           :destination => '/etc/init/monit.conf',
           :permissions => 0644,
           :user => 'root',
           :group => 'root'
       }) { sudo 'initctl reload-configuration' }

end


