module Pvcglue
  class Packages
    class Firewall < Pvcglue::Packages
      def installed?
        false
      end

      def install!
        connection.write_to_file_from_template(:root, 'ufw.rules6.erb', '/etc/ufw/user6.rules')
        connection.write_to_file_from_template(:root, 'ufw.rules.erb', '/etc/ufw/user.rules')
        # connection.run(:root, 'DEBIAN_FRONTEND=noninteractive apt-get update -y -qq')
        # set_minion_state(:last_apt_updated_at, Time.now.utc)
      end

    end
  end
end
