module Pvcglue
  class Packages
    class Firewall < Pvcglue::Packages
      # Reference:  http://manpages.ubuntu.com/manpages/xenial/en/man8/ufw-framework.8.html
      # Examples:  https://help.ubuntu.com/community/UFW
      def installed?
        result = connection.run_get_stdout!(:root, '', 'ufw status verbose')
        result =~ /Status: active/ && result =~ /Default: deny \(incoming\), allow \(outgoing\)/
      end

      def install!
        connection.run!(:root, '', 'ufw disable; ufw --force reset; ufw allow ssh; ufw --force enable')
        # connection.run!(:root, '', 'ufw logging off')
        connection.run!(:root, '', 'ufw logging low')

        if has_role?(:lb)
          connection.run!(:root, '', 'ufw allow http')
          connection.run!(:root, '', 'ufw allow https')
        end

        unless has_role?(:manager)
          minion.cloud.minions.each do |other_minion_name, other_minion|
            next if other_minion_name == minion.machine_name
            connection.run!(:root, '', "ufw allow from #{other_minion.private_ip}")
          end
        end

      end

    end
  end
end
