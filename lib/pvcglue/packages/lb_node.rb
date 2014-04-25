#=======================================================================================================================
package 'lb' do
#=======================================================================================================================
  depends_on 'nginx'
  depends_on 'lb-config'
  depends_on 'lb-maintenance-files'
  # apply do
  #   trigger 'nginx:restart' # files are copied first using 'depends_on' then we restart.
  # end

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
           :destination => "/etc/nginx/sites-enabled/#{Pvcglue.cloud.app_and_stage_name}",
           :create_dirs => false,
           :permissions => 0644,
           :user => 'root',
           :group => 'root'
       }) { sudo('service nginx restart') }
end

package 'lb-maintenance-files' do
  apply do
    run(%(mkdir -p #{Pvcglue.cloud.maintenance_files_dir}))
    cmd = (%(rsync -rzv --exclude=maintenance.on --delete -e ssh #{Pvcglue.configuration.app_maintenance_files_dir}/ #{node.get(:user)}@#{node.host}:#{Pvcglue.cloud.maintenance_files_dir}/))
    raise $?.to_s unless system(cmd)
  end
end

#=======================================================================================================================
package 'maintenance_mode' do
#=======================================================================================================================
  apply do
    if Pvcglue.cloud.maintenance_mode == 'on'
      run "touch #{Pvcglue.cloud.maintenance_mode_file_name}"
    else
      run "rm #{Pvcglue.cloud.maintenance_mode_file_name}"
    end
  end
end
