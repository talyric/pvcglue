package 'web' do
  # rvm/ruby install based on http://ryanbigg.com/2010/12/ubuntu-ruby-rvm-rails-and-you/
  depends_on 'swap' # needed for deployment/asset building on < 1GB machines
  depends_on 'build-essential'
  depends_on 'monit'
  depends_on 'git'
  depends_on 'rvm'
  depends_on 'no-rdoc'


  depends_on 'rvm-ruby'
  depends_on 'bundler'
  depends_on 'nginx'
  depends_on 'phusion-passenger'
  depends_on 'app-env'
  depends_on 'web-site-config'

  depends_on 'imagemagick' # TODO:  app specific--will need to make system to include extra packages
  depends_on 'libpq-dev' # for pg gem
  depends_on 'nodejs'
end


package 'web-site-config' do
  depends_on 'web-get-passenger-ruby'
  file({
           :template => Pvcglue.template_file_name('web.sites-enabled.erb'),
           :destination => "/etc/nginx/sites-enabled/#{Pvcglue.cloud.app_and_stage_name}",
           :create_dirs => false,
           :permissions => 0644,
           :user => 'root',
           :group => 'root'
       }) { sudo('service nginx restart') }
end

package 'web-get-passenger-ruby' do
  apply do
    info = run("rvm use #{Pvcglue.configuration.ruby_version} && $(which passenger-config) --ruby-command")
    if info =~ /passenger_ruby (.*)/
      Pvcglue.cloud.passenger_ruby = $1
    else
      raise "'passenger_ruby' not found." unless Pvcglue.cloud.passenger_ruby
    end
  end
end

package 'phusion-passenger' do
  depends_on 'phusion-repository'
  depends_on 'passenger'
  validate do
    run('passenger -v') =~ /Phusion Passenger version 4/
  end

  file({
           :template => Pvcglue.template_file_name('web.nginx.conf.erb'),
           :destination => '/etc/nginx/nginx.conf',
           :permissions => 0644,
           :user => 'root',
           :group => 'root'
       }) { trigger 'nginx:restart' }
end
