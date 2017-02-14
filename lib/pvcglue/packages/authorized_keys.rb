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
        data = minion.get_root_authorized_keys_data
        if data.count == 0
          # TODO:  work out system for pvc-manager access
          data = [`cat ~/.ssh/id_rsa.pub`.strip]
        end
        connection.write_to_file(:root, data.join("\n"), '/root/.ssh/authorized_keys')

        connection.mkdir_p(:root, "/home/#{user_name}/.ssh", user_name, user_name, '0700')
        data = minion.get_users_authorized_keys_data
        if data.count == 0
          # TODO:  work out system for pvc-manager access
          data = [`cat ~/.ssh/id_rsa.pub`.strip]
        end
        connection.write_to_file(:root, data.join("\n"), "/home/#{user_name}/.ssh/authorized_keys", user_name, user_name, '0644')
      end
    end
  end
end
