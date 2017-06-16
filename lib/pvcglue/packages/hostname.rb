module Pvcglue
  class Packages
    class Hostname < Pvcglue::Packages
      def installed?
        get_minion_state
      end

      def install!
        docs.level_2('Hostname')
        docs.set_item(
          heading: 'Set the hostname',
          body: 'Set the host name to match the machine_name.',
          references: [
            'https://www.linode.com/docs/getting-started',
            'https://askubuntu.com/questions/59458/error-message-when-i-run-sudo-unable-to-resolve-host-none',
            ''
          ]
        ) do
          connection.run!(:root, '', "hostnamectl set-hostname #{minion.machine_name}")
          connection.write_to_file_from_template(:root, 'hosts.erb', '/etc/hosts')
        end
      end

      def post_install_check?
        connection.run_get_stdout(:root, '', 'hostnamectl --static') =~ /#{minion.machine_name}/
      end

      def post_install!
        set_minion_state
      end
    end
  end
end
