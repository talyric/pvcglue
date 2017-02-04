module Pvcglue
  class Packages
    class Web < Pvcglue::Packages
      def installed?
        false
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

      def install!
        connection.write_to_file_from_template(:root, 'lb.nginx.conf.erb', '/etc/nginx/nginx.conf')
        connection.write_to_file_from_template(:root, 'lb.sites-enabled.erb', "/etc/nginx/sites-enabled/#{Pvcglue.cloud.app_and_stage_name}")
        Pvcglue::Packages::Rvm.apply(minion)
        Pvcglue::Packages::Ruby.apply(minion)

        # Pvcglue.cloud.nodes_in_stage(:web).each {|k, v| puts v.machine_name}

        # file({
        #          :template => Pvcglue.template_file_name('lb.nginx.conf.erb'),
        #          :destination => '/etc/./nginx/nginx.conf', # !!! Yes the extra '.' is important !!!  It makes this nginx.conf a 'different' nginx.conf than the web server.  Seems to be a "feature" of the orca gem.
        #          :create_dirs => false,
        #          :permissions => 0644,
        #          :user => 'root',
        #          :group => 'root'
        #      }) { sudo('service nginx restart') }
        #
        # file({
        #          :template => Pvcglue.template_file_name('lb.sites-enabled.erb'),
        #          :destination => "/etc/./nginx/sites-enabled/#{Pvcglue.cloud.app_and_stage_name}", # !!! Yes the extra '.' is important !!!  It makes this nginx.conf a 'different' nginx.conf than the web server.  Seems to be a "feature" of the orca gem.
        #          :create_dirs => false,
        #          :permissions => 0644,
        #          :user => 'root',
        #          :group => 'root'
        #      }) { sudo('service nginx restart') }

      end
    end
  end
end
