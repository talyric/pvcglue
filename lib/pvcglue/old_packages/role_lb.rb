package 'lb' do
  depends_on 'nginx' # DONE
  depends_on 'ssl-cert' # LATER
  depends_on 'lb-config' # DONE
  depends_on 'lb-maintenance-files' # DONE
  depends_on 'monit-bootstrap' # LATER

  validate do
    trigger('nginx:running')
  end

end

package 'lb-config' do
  file({
           :template => Pvcglue.template_file_name('lb.nginx.conf.erb'),
           :destination => '/etc/./nginx/nginx.conf', # !!! Yes the extra '.' is important !!!  It makes this nginx.conf a 'different' nginx.conf than the web server.  Seems to be a "feature" of the orca gem.
           :create_dirs => false,
           :permissions => 0644,
           :user => 'root',
           :group => 'root'
       }) { sudo('service nginx restart') }

  file({
           :template => Pvcglue.template_file_name('lb.sites-enabled.erb'),
           :destination => "/etc/./nginx/sites-enabled/#{Pvcglue.cloud.app_and_stage_name}", # !!! Yes the extra '.' is important !!!  It makes this nginx.conf a 'different' nginx.conf than the web server.  Seems to be a "feature" of the orca gem.
           :create_dirs => false,
           :permissions => 0644,
           :user => 'root',
           :group => 'root'
       }) { sudo('service nginx restart') }
end

package 'lb-maintenance-files' do
  apply do
    source_dir = Pvcglue.configuration.app_maintenance_files_dir
    dest_dir = Pvcglue.cloud.maintenance_files_dir
    # run on remote
    run(%(mkdir -p #{dest_dir}))
    # run rsync from local machine (and it will connect to remote)
    cmd = (%(rsync -rzv --exclude=maintenance.on --delete -e 'ssh -p #{Pvcglue.cloud.port_in_node_context}' #{source_dir}/ #{node.get(:user)}@#{node.host}:#{dest_dir}/))
    raise $?.to_s unless system(cmd)
  end
end

package 'maintenance_mode' do
  apply do
    if Pvcglue.cloud.maintenance_mode == 'on'
      run "touch #{Pvcglue.cloud.maintenance_mode_file_name}"
    else
      run "rm #{Pvcglue.cloud.maintenance_mode_file_name}"
    end
  end
end

package 'bypass_mode' do # LATER
  apply do
    if Pvcglue.cloud.bypass_mode == 'off'
      run "touch #{Pvcglue.cloud.maintenance_bypass_mode_file_name}"
    else
      run "rm #{Pvcglue.cloud.maintenance_bypass_mode_file_name}"
    end
  end
end

package 'ssl-cert' do
  apply do
    if Pvcglue.cloud.ssl_mode == :load_balancer_force_ssl
      sudo(%(mkdir -p #{Pvcglue.cloud.nginx_config_ssl_path}))
      sudo(%Q[echo '#{Pvcglue.cloud.ssl_crt}' | sudo tee #{Pvcglue.cloud.nginx_ssl_crt_file_name} && sudo chmod 600 #{Pvcglue.cloud.nginx_ssl_crt_file_name}])
      sudo(%Q[echo '#{Pvcglue.cloud.ssl_key}' | sudo tee #{Pvcglue.cloud.nginx_ssl_key_file_name} && sudo chmod 600 #{Pvcglue.cloud.nginx_ssl_key_file_name}])
      # TODO:  Restart nginx!!!
    end
  end
end
