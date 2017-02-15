apt_package 'postgresql' do  # DONE
  action('start') { sudo 'service postgresql start' }
  action('stop') { sudo 'service postgresql stop' }
  action('restart') { sudo('service postgresql restart') }
end

package 'postgres' do # DONE
  depends_on 'postgresql', 'libpq-dev'
end

