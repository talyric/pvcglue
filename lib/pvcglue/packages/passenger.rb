apt_package 'apt-transport-https'
apt_package 'passenger'

package 'phusion-sources-list' do
  file({
           :template => Pvcglue.template_file_name('passenger.list.erb'),
           :destination => '/etc/apt/sources.list.d/passenger.list',
           :permissions => 644,
           :user => 'root',
           :group => 'root'
       }) { trigger 'apt:update', true
  }

end

package 'phusion-apt-key' do
  apply do
    sudo "apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 561F9B9CAC40B2F7"
  end
end

package 'phusion-repository' do
  # http://www.modrails.com/documentation/Users%20guide%20Nginx.html#install_on_debian_ubuntu
  depends_on 'apt-transport-https'
  depends_on 'phusion-apt-key'
  depends_on 'phusion-sources-list'
end

package 'phusion-passenger' do
  validate do
    run('passenger -v') =~ /Phusion Passenger version 4/
  end
  depends_on 'phusion-repository'
  depends_on 'passenger'

  file({
           :source => 'files/web.nginx.conf',
           :destination => '/etc/nginx/nginx.conf',
           :permissions => 0644,
           :user => 'root',
           :group => 'root'
       }) { trigger 'nginx:restart' }
end
