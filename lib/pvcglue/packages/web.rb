module Pvcglue
  class Packages
    class Web < Pvcglue::Packages

      def installed?
        false
      end

      def install!
        Pvcglue::Packages::DirBase.apply(minion)
        Pvcglue::Packages::DirShared.apply(minion)
        Pvcglue::Packages::Rvm.apply(minion)
        Pvcglue::Packages::Ruby.apply(minion)
        # Pvcglue::Packages::Secrets.apply(minion)  # TODO:  Apply secrets after all servers are built
        connection.write_to_file_from_template(:root, 'web.nginx.conf.erb', '/etc/nginx/nginx.conf')

        set_passenger_ruby # needs to be set before rendering 'web.sites-enabled.erb'
        connection.write_to_file_from_template(:root, 'web.sites-enabled.erb', "/etc/nginx/sites-enabled/#{Pvcglue.cloud.app_and_stage_name}")


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

      def set_passenger_ruby
        info = connection.run_get_stdout!(user_name, '', "rvm use #{Pvcglue.configuration.ruby_version} && $(which passenger-config) --ruby-command")
        if info =~ /passenger_ruby (.*)/
          Pvcglue.cloud.passenger_ruby = $1
        else
          raise "'passenger_ruby' not found." unless Pvcglue.cloud.passenger_ruby
        end

      end
    end
  end
end
