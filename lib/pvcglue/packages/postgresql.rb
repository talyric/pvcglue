apt_package 'postgresql' do
  action('start') { sudo 'service postgresql start' }
  action('stop') { sudo 'service postgresql stop' }
  action('restart') { sudo('service postgresql restart') }
end

package 'postgres' do
  depends_on 'postgresql', 'libpq-dev'
end

