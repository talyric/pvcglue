module Pvcglue
  class Packages
    class Apt < Pvcglue::Packages
      WEB_WORKER_PACKAGES = %w[
        build-essential
        git
        git-core
        libpq-dev
        libxml2
        libxml2-dev
        imagemagick
        passenger
        nginx
        nginx-extras
        nodejs
      ]
      PACKAGES = {
          common: %w[
        htop
        ufw
        unattended-upgrades
        curl
        ncdu
          ],
          manager: %w[
            git
            git-core
          ],
          lb: %w[
            nginx
            nginx-extras
          ],
          web: WEB_WORKER_PACKAGES,
          worker: WEB_WORKER_PACKAGES,
          pg: %w[
          ],
          mc: %w[
          ],
      }

      def installed?
        false # just let apt take care of this for now
      end

      def install!
        connection.run!(:root, '', "DEBIAN_FRONTEND=noninteractive apt install -y #{get_package_list}")
      end

      def get_package_list
        get_packages.join(' ')
      end

      def post_install_check?
        true
      end

      def all_packages
        @all_packages ||= PACKAGES.with_indifferent_access
      end

      def get_packages
        packages = all_packages[:common]
        minion.roles.each do |role|
          packages += all_packages[role] if all_packages[role]
        end
        packages
      end

    end
  end
end
