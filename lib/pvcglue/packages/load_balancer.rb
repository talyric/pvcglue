module Pvcglue
  class Packages
    class LoadBalancer < Pvcglue::Packages
      def installed?
        false
      end

      def install!
        connection.write_to_file_from_template(:root, 'lb.nginx.conf.erb', '/etc/nginx/nginx.conf')
        connection.write_to_file_from_template(:root, 'lb.sites-enabled.erb', "/etc/nginx/sites-enabled/#{Pvcglue.cloud.app_and_stage_name}")
        sync_maintenance_files
      end

      def post_install_check?
        result = connection.run_get_stdout(:root, '', 'service nginx restart')
        if $?.exitstatus == 0
          # Pvcglue.logger.debug { result }
          true
        else
          Pvcglue.logger.error { 'Unable to (re)start nginx.  Getting status...' }
          result = connection.run_get_stdout(:root, '', 'systemctl status nginx.service')
          puts result
          false
        end
        # TODO:  Ping the server as a double check.
      end

      def sync_maintenance_files
        source_dir = Pvcglue.configuration.app_maintenance_files_dir
        dest_dir = Pvcglue.cloud.maintenance_files_dir
        connection.rsync_up(user_name, '-rzv --exclude=maintenance.on --delete', source_dir, dest_dir, mkdir = true)
      end
    end
  end
end
