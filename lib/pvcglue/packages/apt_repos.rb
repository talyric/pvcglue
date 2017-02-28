module Pvcglue
  class Packages
    class AptRepos < Pvcglue::Packages
      PASSENGER_SOURCES_LIST_FILENAME = '/etc/apt/sources.list.d/passenger.list'
      PASSENGER_SOURCES_LIST_DATA = 'deb https://oss-binaries.phusionpassenger.com/apt/passenger xenial main'

      def nginx_needed?
        has_roles? %w(lb web)
      end

      def node_js_needed?
        has_roles? %w(web worker)
      end

      def postgresql_needed?
        has_roles? %w(pg)
      end

      def installed?
        get_minion_state(:apt_repos_updated_at)
      end

      def install!
        # TODO: Make this a package that checks for the existence of software-properties-common
        #echo 'Acquire::ForceIPv4 "true";' | tee /etc/apt/apt.conf.d/99force-ipv4
        connection.write_to_file(:root, 'Acquire::ForceIPv4 "true";', '/etc/apt/apt.conf.d/99force-ipv4')

        connection.run!(:root, '', 'apt update -y')
        connection.run!(:root, '', 'apt update -y')
        connection.run!(:root, '', 'apt install -y software-properties-common python-software-properties')

        # These could be refactored into packages.  :)

        if nginx_needed?
          # Reference:  https://www.phusionpassenger.com/library/install/nginx/install/oss/xenial/
          connection.run!(:root, '', 'apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7')
          connection.run!(:root, '', 'apt-get install -y apt-transport-https ca-certificates')
          connection.write_to_file(:root, PASSENGER_SOURCES_LIST_DATA, PASSENGER_SOURCES_LIST_FILENAME)
        end

        if node_js_needed?
          # Reference:  http://tecadmin.net/install-latest-nodejs-npm-on-ubuntu/
          connection.run!(:root, '', 'apt-get install -y apt-transport-https ca-certificates python-software-properties lsb-release')
          connection.run!(:root, '', 'curl -sL https://deb.nodesource.com/setup_7.x | bash -')
        end

        if postgresql_needed?
          connection.run!(:root, '', 'add-apt-repository "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main"')
          connection.run!(:root, '', 'wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -')
        end

        set_minion_state(:apt_repos_updated_at, Time.now.utc)
      end
    end
  end
end
