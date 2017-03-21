module Pvcglue
  class Packages
    class AptRepos < Pvcglue::Packages
      PASSENGER_SOURCES_LIST_FILENAME = '/etc/apt/sources.list.d/passenger.list'
      PASSENGER_SOURCES_LIST_DATA = 'deb https://oss-binaries.phusionpassenger.com/apt/passenger xenial main'

      def nginx_needed?
        has_roles? %w(lb web)
      end

      def redis_needed?
        # has_roles? %w(redis)
        has_roles? %w(redis web worker) # web worker will just have package `redis-tools`
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
        docs.level_2('Repositories')

        # TODO: Make this a package that checks for the existence of software-properties-common
        #echo 'Acquire::ForceIPv4 "true";' | tee /etc/apt/apt.conf.d/99force-ipv4
        docs.set_item(
          heading: 'Force use of IPv4',
          body: 'Needed for Linode as there were intermittent problems connecting to their repositories over IPv6 (February 2017)'
        ) do
          connection.write_to_file(:root, 'Acquire::ForceIPv4 "true";', '/etc/apt/apt.conf.d/99force-ipv4')
        end


        docs.set_item(
          heading: 'Update Repositories'
        ) do
          connection.run!(:root, '', 'apt update -y')
        end
        docs.set_item(
          heading: 'Install Requirements',
          body: 'Install the requirements for adding more repositories'
        ) do
          connection.run!(:root, '', 'apt install -y software-properties-common python-software-properties')
        end
        # These could be refactored into packages.  :)

        if nginx_needed?
          docs.set_item(
            heading: 'Nginx',
            body: 'Install the latest version using the Phusion repos.',
            reference: 'https://www.phusionpassenger.com/library/install/nginx/install/oss/xenial/'
          ) do
            connection.run!(:root, '', 'apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7')
            connection.run!(:root, '', 'apt-get install -y apt-transport-https ca-certificates')
            connection.write_to_file(:root, PASSENGER_SOURCES_LIST_DATA, PASSENGER_SOURCES_LIST_FILENAME)
          end
        end

        if redis_needed?
          docs.set_item(
            heading: 'Redis',
            body: 'Install the latest stable version.  The current Ubuntu version is apparently behind on security updates.',
            reference: 'https://www.linode.com/docs/databases/redis/deploy-redis-on-ubuntu-or-debian'
          ) do
            connection.run!(:root, '', 'add-apt-repository "ppa:chris-lea/redis-server"')
          end
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
        # byebug # docs resume here

        set_minion_state(:apt_repos_updated_at, Time.now.utc)
      end
    end
  end
end
