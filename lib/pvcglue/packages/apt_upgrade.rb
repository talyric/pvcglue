module Pvcglue
  class Packages
    class AptUpgrade < Pvcglue::Packages
      def installed?
        # TODO:  Add a "force" option
        updated_at = get_minion_state(:apt_upgraded_at)
        return false unless updated_at

        # updated_at > Time.now.utc - 8.hours
        # TODO:  Give the user a warning after a period of time
        true
      end

      def install!
        minion.connection.run!(:root, '', 'DEBIAN_FRONTEND=noninteractive apt-get upgrade -y')
        set_minion_state(:apt_upgraded_at, Time.now.utc)
      end
    end
  end
end
