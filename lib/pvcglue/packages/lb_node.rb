#=======================================================================================================================
package 'lb' do
#=======================================================================================================================
  depends_on 'nginx'
  depends_on 'lb-config'
  depends_on 'lb-maintenance-files'
  apply do
    trigger 'nginx:restart' # files are copied first using 'depends_on' then we restart.
  end

  validate do
    trigger('nginx:running')
  end

end

package 'lb-config' do
  apply do
    raise 'missing options' if ENV['PVC_DEPLOY_TO_BASE'].blank? || ENV['PVC_APP_NAME'].blank? || ENV['PVC_STAGE'].blank? || ENV['PVC_DOMAIN'].blank? || ENV['PVC_DEPLOY_TO_APP'].blank? || ENV['PVC_STAGE_JSON'].blank?
    stage_data = JSON.parse(ENV['PVC_STAGE_JSON']).with_indifferent_access
    app_stage_name = "#{ENV['PVC_APP_NAME']}_#{ENV['PVC_STAGE']}".downcase
    deploy_to_app_base = ENV['PVC_DEPLOY_TO_APP']
    conf_file_name = "/etc/nginx/sites-enabled/#{app_stage_name}"
    web_servers = stage_data[:nodes][:web].map { |_, value| "  server #{value[:private_ip]} max_fails=1 fail_timeout=10s;" }.join("\n      ").rstrip

    maintenance_config = %(

        # partially based on https://onehub.com/blog/2009/03/06/rails-maintenance-pages-done-right/
        recursive_error_pages on;

        set $maintenance off;

        if (-f $document_root/maintenance/maintenance.on) {
          set $maintenance on;
        }

        if ($remote_addr = 68.189.112.146) {
          set $maintenance off;
        }

        if ($uri ~ ^/maintenance/.*) {
          set $maintenance off;
        }

        if ($maintenance = on) {
          return 503; # 503 - Service unavailable
        }

        location /maintenance {
        }

        #error_page 404 /404.html;
        #error_page 500 502 504 /500.html;
        error_page 503 @503;

        location @503 {

          error_page 405 = /maintenance/maintenance.html;

          # Serve static assets if found.
          rewrite ^(.*)$ /maintenance/maintenance.html break;
        }

    )

    denial_of_service_protection_config = %(

      limit_conn conn_limit_per_ip 10;
      limit_req zone=req_limit_per_ip burst=30 nodelay;

    )

    conf = %(
      upstream #{app_stage_name}_application  {
      #{web_servers}
      }
      server {
        listen 80;
        #listen         [::]:80;
        server_name #{stage_data[:domain]};

        access_log  /var/log/nginx/#{app_stage_name}.access.log;
        error_log  /var/log/nginx/#{app_stage_name}.error.log;

        root #{deploy_to_app_base};

        #{denial_of_service_protection_config}
    #{maintenance_config}

    )
    case stage_data[:ssl].to_sym
      when :none
        conf += %(
        location / {
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

          proxy_pass  http://#{app_stage_name}_application;
        }

      )
      when :load_balancer_force_ssl
        conf += %(
        location / {
          # According to http://serverfault.com/a/401632/156820 this is the correct way to redirect all http to https
          return 301 https://$host$request_uri;
        }
      )

      else
        raise "Unsupported SSL option '#{stage_data[:ssl]}'"
    end
    conf += %(

      }
      server {
        listen 443;
        server_name #{stage_data[:domain]};

        access_log  /var/log/nginx/#{app_stage_name}.ssl.access.log;
        error_log  /var/log/nginx/#{app_stage_name}.ssl.error.log;

        root #{deploy_to_app_base};

        #{denial_of_service_protection_config}
    #{maintenance_config}

    )
    case stage_data[:ssl].to_sym
      when :none
        conf += %(
        #ssl on;
        #ssl_certificate cert.crt;
        #ssl_certificate_key cert.key;
      )
      when :load_balancer_force_ssl
        conf += %(
        ssl on;
        ssl_certificate /etc/nginx/ssl/#{app_stage_name}.crt;
        ssl_certificate_key /etc/nginx/ssl/#{app_stage_name}.key;
      )
      else
        raise "Unsupported SSL option '#{stage_data[:ssl]}'"
    end
    conf += %(

        location / {

          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto https;

          proxy_pass  http://#{app_stage_name}_application;
          #proxy_redirect http://jrubyapp.example.com https://jrubyapp.example.com;  #Check this setting
        }

      }
    )
    sudo(%Q[echo '#{conf}' | sudo tee #{conf_file_name}])

    puts conf_file_name
    puts sudo("cat #{conf_file_name}")
    trigger 'nginx:restart' # may want to skip this unless the files changed...

  end
end

package 'lb-maintenance-files' do
  file({
           :template => Pvcglue.template_file_name('lb.nginx.conf'),
           :destination => '/etc/./nginx/nginx.conf', # !!! Yes the extra '.' is important !!!  It makes this nginx.conf a 'different' nginx.conf than the web server.  Seems to be a "feature" of the orca gem.
           :permissions => 0644,
           :user => 'root',
           :group => 'root'
       })
  file({
           :source => 'files/maintenance.html',
           :destination => File.join(ENV['PVC_DEPLOY_TO_APP'], 'maintenance', 'maintenance.html'),
           :create_dirs => true,
           :permissions => 0644,
           :user => 'deploy',
           :group => 'deploy'
       })
  file({
           :source => 'files/maintenance.css',
           :destination => File.join(ENV['PVC_DEPLOY_TO_APP'], 'maintenance', 'maintenance.css'),
           :create_dirs => true,
           :permissions => 0644,
           :user => 'deploy',
           :group => 'deploy'
       })
  file({
           :source => 'files/custom.css',
           :destination => File.join(ENV['PVC_DEPLOY_TO_APP'], 'maintenance', 'custom.css'),
           :create_dirs => true,
           :permissions => 0644,
           :user => 'deploy',
           :group => 'deploy'
       })
  file({
           :source => 'files/maintenance.png',
           :destination => File.join(ENV['PVC_DEPLOY_TO_APP'], 'maintenance', 'maintenance.png'),
           :create_dirs => true,
           :permissions => 0644,
           :user => 'deploy',
           :group => 'deploy'
       })

end

#=======================================================================================================================
package 'maintenance_mode' do
#=======================================================================================================================
  apply do
    if ENV['PVC_MAINTENANCE_MODE'] == 'on'
      run "touch #{File.join(ENV['PVC_DEPLOY_TO_APP'], 'maintenance', 'maintenance.on')}"
    else
      run "rm #{File.join(ENV['PVC_DEPLOY_TO_APP'], 'maintenance', 'maintenance.on')}"
    end
  end
end
