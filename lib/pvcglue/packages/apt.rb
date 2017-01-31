module Pvcglue
  class Packages
    class Apt < Pvcglue::Packages
      PACKAGES = {
          common: %w[
        htop
        ufw
        unattended-upgrades
        curl
        ncdu
          ],
          lb: %w[
          ],
          web: %w[
          ],
          worker: %w[
          ],
          pg: %w[
          ],
          mc: %w[
          ],
      }
      PACKAGE_LIST = %w(
        build-essential
        git
        git-core
        libpq-dev
        libxml2
        libxml2-dev
        libxslt
        libxslt1-dev
        imagemagick

      )

      @test = false

      def installed?
        @test
      end

      def install!
        @test = true
        minion.connection.run(:root, 'apt install htop')
      end
    end
  end
end
