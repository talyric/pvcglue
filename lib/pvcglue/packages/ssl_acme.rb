module Pvcglue
  class Packages
    class SslAcme < Pvcglue::Packages
      def installed?
        return true if Pvcglue.cloud.ssl_mode == :none
        get_minion_state(:acme_sh_updated_at)
      end

      def install!
        # Thanks to https://www.rmedgar.com/blog/using-acme-sh-with-nginx

        connection.ssh!(:root, '', 'curl https://get.acme.sh | sh')

        # mkdir -p /var/www/le_root/.well-known/acme-challenge
        connection.mkdir_p(:root, Pvcglue.cloud.letsencrypt_full)
        #chown -R root:www-data /var/www/le_root
        connection.chown(:root, Pvcglue.cloud.letsencrypt_root, 'root', 'www-data', '-R')

        # Test with http://www.example.com/.well-known/acme-challenge/test.html
        connection.write_to_file(:root, "Everything's shiny, Cap'n. Not to fret.", File.join(Pvcglue.cloud.letsencrypt_full, 'test.html'), 'root', 'www-data', '660')

        connection.ssh!(:root, '', 'systemctl reload nginx.service')

        set_minion_state(:acme_sh_updated_at, Time.now.utc)
      end

    end
  end
end
