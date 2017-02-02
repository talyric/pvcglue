module Pvcglue
  class Packages
    class AptRepos < Pvcglue::Packages
      PASSENGER_SOURCES_LIST_FILENAME = '/etc/apt/sources.list.d/passenger.list'
      PASSENGER_SOURCES_LIST_DATA = 'deb https://oss-binaries.phusionpassenger.com/apt/passenger xenial main'

      def nginx_needed?
        has_roles? %w(lb web)
      end

      def installed?
        return true if get_minion_state(:apt_repos_updated_at)
        if nginx_needed?
          connection.file_matches?(:root, PASSENGER_SOURCES_LIST_DATA, PASSENGER_SOURCES_LIST_FILENAME)
        end
      end

      def install!
        # Reference:  https://www.phusionpassenger.com/library/install/nginx/install/oss/xenial/
        connection.run!(:root, '', 'apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7')
        connection.run!(:root, '', 'apt-get install -y apt-transport-https ca-certificates')
        connection.write_to_file(:root, PASSENGER_SOURCES_LIST_DATA, PASSENGER_SOURCES_LIST_FILENAME)

        set_minion_state(:apt_repos_updated_at, Time.now.utc)
      end
    end
  end
end
