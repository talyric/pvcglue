module Pvcglue
  class Packages
    class AptUpdate < Pvcglue::Packages
      def installed?
        # TODO:  Add a "force" option
        updated_at = get_minion_state(:last_apt_updated_at)
        return false unless updated_at
        true
        # updated_at > Time.now.utc - 8.hours # Unattended upgrades should take care of refreshing this automatically
      end

      def install!
        connection.run!(:root, '', 'DEBIAN_FRONTEND=noninteractive apt-get update -y -qq')
        set_minion_state(:last_apt_updated_at, Time.now.utc)
      end
    end
  end
end
