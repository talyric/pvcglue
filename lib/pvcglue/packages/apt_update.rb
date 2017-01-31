module Pvcglue
  class Packages
    class AptUpdate < Pvcglue::Packages
      LAST_APT_UPDATE_FILENAME = '.pvc_last_apt_update.dat'

      def installed?
        # TODO:  Add a "force" option
        data = nil
        if minion.connection.file_exists?(:root, LAST_APT_UPDATE_FILENAME)
          data = minion.connection.read_from_file(:root, LAST_APT_UPDATE_FILENAME)
        end
        return false unless data
        begin
          updated_at = DateTime.parse(JSON.parse(data)['updated_at'])
          # TODO:  Possible timezone issue
          updated_at > Time.now - 8.hours
        rescue JSON::ParserError
          false
        end
      end

      def install!
        minion.connection.run(:root, 'DEBIAN_FRONTEND=noninteractive apt-get update -y -qq')
        # TODO:  Possible timezone issue
        data = {updated_at: Time.now}
        minion.connection.write_to_file(:root, data.to_json, LAST_APT_UPDATE_FILENAME)
      end
    end
  end
end
