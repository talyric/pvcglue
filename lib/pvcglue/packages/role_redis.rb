apt_package 'redis-server'

package 'redis' do
  depends_on 'redis-server'
  file({
           :template => Pvcglue.template_file_name('redis.conf.erb'),
           :destination => '/etc/redis/redis.conf',
           :create_dirs => false,
           :permissions => 0644,
           :user => 'root',
           :group => 'root'
       }) { sudo('service redis-server restart') }
end

