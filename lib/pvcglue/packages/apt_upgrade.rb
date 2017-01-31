module Pvcglue
  class Packages
    class AptUpgrade < Pvcglue::Packages
      LAST_APT_UPGRADE_FILENAME = '.pvc_last_apt_upgrade.dat'

      def installed?
        # TODO:  Add a "force" option
        data = nil
        if minion.connection.file_exists?(:root, LAST_APT_UPGRADE_FILENAME)
          data = minion.connection.read_from_file(:root, LAST_APT_UPGRADE_FILENAME)
        end
        return false unless data
        # begin
        #   upgraded_at = DateTime.parse(JSON.parse(data)['upgraded_at'])
        #   # TODO:  Possible timezone issue
        #   upgraded_at > Time.now - 8.hours
        # rescue JSON::ParserError
        #   false
        # end
        # TODO:  Give the user a warning after a period of time
        true
      end

      def install!
        minion.connection.run(:root, 'DEBIAN_FRONTEND=noninteractive apt-get upgrade -y')
        # TODO:  Possible timezone issue
        data = {upgraded_at: Time.now}
        minion.connection.write_to_file(:root, data.to_json, LAST_APT_UPGRADE_FILENAME)
      end
    end
  end
end
