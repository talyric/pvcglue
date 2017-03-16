module Pvcglue
  class Packages
    class LoadBalancer < Pvcglue::Packages
      def installed?
        false
      end

      def install!
        sync_maintenance_files

        if Pvcglue.cloud.ssl_mode == :acme && !connection.file_exists?(:root, Pvcglue.cloud.nginx_ssl_crt_file_name)
          # Don't include the SSL stuff in the Nginx config until we have a cert,
          # but Nginx has to be configured to get the cert from Let's Encrypt
          Pvcglue.cloud.set_ssl_mode_override(:none)
        end

        apply_nginx_includes
        apply_nginx_config
        nginx_restart!

        Pvcglue::Packages::Ssl.apply(minion)

        if Pvcglue.cloud.ssl_mode_override
          Pvcglue.cloud.set_ssl_mode_override(nil)
          apply_nginx_config
          nginx_restart!
        end

      end

      def nginx_restart!
        result = connection.run_get_stdout(:root, '', 'service nginx restart')
        if $?.exitstatus == 0
          # Pvcglue.logger.debug { result }
          # true
        else
          Pvcglue.logger.error { 'Unable to (re)start nginx.  Getting status...' }
          result = connection.run_get_stdout(:root, '', 'systemctl status nginx.service')
          puts result
          raise
        end
      end

      def apply_nginx_includes
        connection.mkdir_p(:root, '/etc/nginx/includes')
        connection.write_to_file_from_template(:root, 'letsencrypt-webroot.erb', '/etc/nginx/includes/letsencrypt-webroot')
      end

      def apply_nginx_config
        connection.write_to_file_from_template(:root, 'lb.nginx.conf.erb', '/etc/nginx/nginx.conf')
        connection.write_to_file_from_template(:root, 'lb.sites-enabled.erb', "/etc/nginx/sites-enabled/#{Pvcglue.cloud.app_and_stage_name}")
      end

      def post_install_check?
        # TODO:  Ping the server as a double check.
        true
      end

      def sync_maintenance_files
        Pvcglue.logger.debug { 'Synchronizing maintenance mode files' }
        source_dir = Pvcglue.configuration.app_maintenance_files_dir
        dest_dir = Pvcglue.cloud.maintenance_files_dir
        maintenance_file_name = File.join(source_dir, 'maintenance.html')
        unless File.exists?(maintenance_file_name)
          Pvcglue.logger.debug { 'Creating default maintenance mode files' }
          # TODO:  Make this use a template
          `mkdir -p #{source_dir}`
          File.write(maintenance_file_name, '-Maintenance Mode-')
        end
        connection.rsync_up(user_name, '-rzv --exclude=maintenance.on --delete', source_dir, dest_dir, mkdir = true)
      end
    end
  end
end
