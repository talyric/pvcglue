module Pvcglue
  class Packages
    class Ssl < Pvcglue::Packages
      def installed?
        return true if Pvcglue.cloud.ssl_mode == :none
        false
      end

      def install!
        # TODO:  Support using already created certs
        return true unless Pvcglue.cloud.ssl_mode == :acme

        Pvcglue::Packages::SslAcme.apply(minion)

        # Issue Certificate
        first_domain = Pvcglue.cloud.domains.first
        domains = Pvcglue.cloud.domains.map { |domain| "-d #{domain}" }
        first_domain_option = domains.first
        domain_options = domains.join(' ')
        staging_option = Pvcglue.command_line_options[:create_test_cert] ? '--staging ' : ''
        force_option = Pvcglue.command_line_options[:force_cert] ? '--force ' : ''
        debug_option = Pvcglue.logger.level == 0 ? '--debug ' : ''

        begin

          # Test with http://www.example.com/.well-known/acme-challenge/test.html
          base_name = "test-#{SecureRandom.hex}.html"
          verification_file_name = File.join(Pvcglue.cloud.letsencrypt_full, base_name)
          connection.write_to_file(:root, "Everything's shiny, Cap'n. Not to fret.", verification_file_name, 'root', 'www-data', '660')

          unless Net::HTTP.get(first_domain, "/.well-known/acme-challenge/#{base_name}") =~ /shiny/
            Pvcglue.logger.error("Unable to connect to #{first_domain} at #{minion.public_ip}")
            raise(Thor::Error, 'Please fix and then restart.')
          end
        ensure
          # TODO:  Delete verification file
        end

        result = connection.ssh?(:root, '', "/root/.acme.sh/acme.sh #{debug_option}#{staging_option}#{force_option}--issue #{domain_options} -w #{Pvcglue.cloud.letsencrypt_root}")
        raise result.inspect unless result.exitstatus == 0 || result.exitstatus == 2

        # Install Certificate
        connection.mkdir_p(:root, Pvcglue.cloud.nginx_config_ssl_path)
        # acme.sh --installcert -d theos.in --keypath /etc/nginx/ssl/theos.in/theos.in.key --fullchainpath /etc/nginx/ssl/theos.in/theos.in.cer --reloadcmd 'systemctl reload nginx'

        connection.ssh!(:root, '', "/root/.acme.sh/acme.sh --installcert #{first_domain_option} --keypath #{Pvcglue.cloud.nginx_ssl_key_file_name} --fullchainpath #{Pvcglue.cloud.nginx_ssl_crt_file_name}  --reloadcmd 'systemctl reload nginx'")
      end

      def post_install_check?
        true
      end

    end
  end
end
