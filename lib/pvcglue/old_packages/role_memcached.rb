apt_package 'memcached'

package 'caching' do
  depends_on 'memcached'
  depends_on 'monit-bootstrap'
  file({
           :template => Pvcglue.template_file_name('memcached.conf.erb'),
           :destination => '/etc/memcached.conf',
           :create_dirs => false,
           :permissions => 0644,
           :user => 'root',
           :group => 'root'
       }) { sudo('service memcached restart') }
end

