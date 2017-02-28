module Pvcglue
  class Packages
    class AuthorizedKeys < Pvcglue::Packages
      def installed?
        false
      end

      def post_install_check?
        true
      end

      def install!
        # TODO:  Safety check to see if user is locking himself out.  :)
        if manager_first_bootstrap?
          # TODO:  work out system for pvc-manager access
          data = [`cat ~/.ssh/id_rsa.pub`.strip]
        else
          data = minion.get_root_authorized_keys_data
          if data.count == 0
            raise('No authorized keys found for root users!')
          end
        end
        connection.write_to_file(:root, data.join("\n"), '/root/.ssh/authorized_keys')

        connection.mkdir_p(:root, "/home/#{user_name}/.ssh", user_name, user_name, '0700')

        if manager_first_bootstrap?
          data = [`cat ~/.ssh/id_rsa.pub`.strip]
        else
          data = minion.get_users_authorized_keys_data
          if data.count == 0
            raise('No authorized keys found for users!')
            # TODO:  work out system for pvc-manager access
          end
        end
        connection.write_to_file(:root, data.join("\n"), user_authorized_keys_file_name, user_name, user_name, '0644')
      end

      def user_authorized_keys_file_name
        "/home/#{user_name}/.ssh/authorized_keys"
      end

      def manager_first_bootstrap?
        return false unless has_role?(:manager)
        @manager_first_bootstrap ||= !Pvcglue::Packages::Manager.configuration_exists?
      end
    end
  end
end
