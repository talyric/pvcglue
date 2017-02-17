module Pvcglue
  class Packages
    class Ssl < Pvcglue::Packages
      def installed?
        return true if Pvcglue.cloud.ssl_mode == :none
        false
      end

      def install!
        return true unless Pvcglue.cloud.ssl_mode == :acme

        install_acme_sh

        # Issue Certificate
        domains = Pvcglue.cloud.domains.map { |domain| "-d #{domain}" }
        first_domain_option = domains.first
        domain_options = domains.join(' ')
        staging_option = Pvcglue.command_line_options[:create_test_cert] ? '--staging ' : ''
        force_option = Pvcglue.command_line_options[:force_cert] ? '--force ' : ''
        debug_option = Pvcglue.logger.level == 0 ? '--debug ' : ''

        result = connection.ssh?(:root, '', "/root/.acme.sh/acme.sh #{debug_option}#{staging_option}#{force_option}--issue #{domain_options} -w #{Pvcglue.cloud.letsencrypt_root}")
        raise result.inspect unless result.exitstatus == 0 || result.exitstatus == 2

        # Install Certificate
        connection.mkdir_p(:root, Pvcglue.cloud.nginx_config_ssl_path)
        # acme.sh --installcert -d theos.in --keypath /etc/nginx/ssl/theos.in/theos.in.key --fullchainpath /etc/nginx/ssl/theos.in/theos.in.cer --reloadcmd 'systemctl reload nginx'
        connection.ssh!(:root, '', "/root/.acme.sh/acme.sh --installcert #{first_domain_option} --keypath #{Pvcglue.cloud.nginx_ssl_key_file_name} --fullchainpath #{Pvcglue.cloud.nginx_ssl_crt_file_name}  --reloadcmd 'systemctl reload nginx'")
      end

      def install_acme_sh
        return if get_minion_state(:acme_sh_updated_at)

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

      def post_install_check?
        true
      end

    end
  end
end
