# Reference http://www.modrails.com/documentation/Users%20guide%20Nginx.html
# 'nginx-extras' is the "everything" install, https://wiki.debian.org/Nginx
apt_package 'nginx', 'nginx-extras' do
  depends_on 'phusion-repository' # Must use nginx from phusion repo to automatically get passenger integration and the latest version
  action('start') { sudo 'service nginx start' }
  action('stop') { sudo 'service nginx stop' }
  action('restart') { trigger('nginx:running') ? sudo('service nginx restart') : trigger('nginx:start') }
  action('running') { run('ps aux | grep [n]ginx') =~ /nginx: master process/ }
  action('reload') { sudo 'pkill -HUP nginx' }
end
