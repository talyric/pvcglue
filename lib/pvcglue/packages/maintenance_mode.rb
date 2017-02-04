module Pvcglue
  class Packages
    class MaintenanceMode < Pvcglue::Packages
      def installed?
        false
      end

      def install!
        if options[:maintenance_mode] == 'on'
          connection.run!(user_name, '', "touch #{Pvcglue.cloud.maintenance_mode_file_name}")
        elsif options[:maintenance_mode] == 'off'
          result = connection.run?(user_name, '', "rm #{Pvcglue.cloud.maintenance_mode_file_name}")
          if result.exitstatus == 1
            Pvcglue.logger.warn('Maintenance mode was already off.')
          elsif result.exitstatus != 0
            raise result.inspect
          end
        else
          raise("Invalid maintenance_mode option:  #{options[:maintenance_mode]}")
        end
      end

      def post_install_check?
        true
      end
    end
  end
end
