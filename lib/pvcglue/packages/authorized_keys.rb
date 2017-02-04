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
        data = minion.get_root_authorized_keys.join("\n")
        # TODO:  Safety check to see if user is locking himself out.  :)
        connection.write_to_file(:root, data, '/root/.ssh/authorized_keys')

        connection.mkdir_p(:root, "/home/#{user_name}/.ssh", user_name, user_name, '0700')
        data = minion.get_users_authorized_keys.join("\n")
        connection.write_to_file(:root, data, "/home/#{user_name}/.ssh/authorized_keys", user_name, user_name, '0644')
      end
    end
  end
end
