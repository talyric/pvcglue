package 'monit-config' do
  file({
           :template => Pvcglue.template_file_name('monit_init.d.erb'),
           :destination => '/etc/init.d/monit',
           :permissions => 755,
           :user => 'root',
           :group => 'root'
       }) { sudo('service monit restart') }

  file({
           :template => Pvcglue.template_file_name('monitrc.erb'),
           :destination => '/etc/monit/monitrc',
           :permissions => 700,
           :user => 'root',
           :group => 'root'
       }) { sudo('service monit restart') }

end

package 'monit' do
  depends_on 'monit-config'

  validate do
    run('monit -V') =~ /5\.14/
  end

  apply do
    # Thanks to https://rtcamp.com/tutorials/monitoring/monit/
    sudo 'wget https://mmonit.com/monit/dist/binary/5.14/monit-5.14-linux-x64.tar.gz'
    sudo 'tar zxvf monit-5.14-linux-x64.tar.gz'
    sudo 'cd monit-5.14/'
    sudo 'cp bin/monit /usr/bin/monit'
    sudo 'ln -s /etc/monit/monitrc /etc/monitrc'
    sudo 'echo "START=yes" > /etc/default/monit'
    sudo 'service monit restart'
  end

  remove do
    raise "removing monit not supported, yet."
  end
end
