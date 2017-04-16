module Pvcglue
  class Packages
    class AuthorizedKeys < Pvcglue::Packages
      def installed?
        false
      end

      def post_install_check?
        true
      end

      def install!
        docs.set_item(
          heading: 'Authorized Users',
          body: 'Configures sshd and the authorized_keys files.',
          notes: [
            ''
          ],
          cheatsheet: [
            '',
          ],
          references: [
            'https://serverfault.com/questions/256098/authorized-keys-environment-variables-not-setting-environment-variables',
            'https://serverfault.com/questions/527638/security-risks-of-permituserenvironment-in-ssh',
            '',
            'https://binblog.info/2008/10/20/openssh-going-flexible-with-forced-commands/',
            'https://www.ibm.com/support/knowledgecenter/en/SSLTBW_2.2.0/com.ibm.zos.v2r2.foto100/authkeyf.htm',
            'https://en.wikibooks.org/wiki/OpenSSH/Client_Configuration_Files#environment.3D.22NAME.3Dvalue.22',
            'http://man.openbsd.org/sshd_config.5',
            'https://developer.rackspace.com/blog/speeding-up-ssh-session-creation/',
          ]
        ) do
          # sshd configuration
          connection.write_to_file_from_template(:root, 'sshd_config.erb', '/etc/ssh/sshd_config')
          connection.run!(:root, '', 'systemctl restart sshd')

          # authorized_keys
          # TODO:  Safety check to see if user is locking himself out.  :)
          if manager_first_bootstrap?
            # TODO:  work out system for pvc-manager access
            data = [`cat ~/.ssh/id_rsa.pub`.strip]
          else
            data = minion.get_root_authorized_keys_data
            if data.count == 0
              raise('No authorized keys found for root users!')
            end
          end
          connection.write_to_file(:root, data.join("\n"), '/root/.ssh/authorized_keys')

          connection.mkdir_p(:root, "/home/#{user_name}/.ssh", user_name, user_name, '0700')

          if manager_first_bootstrap?
            data = [`cat ~/.ssh/id_rsa.pub`.strip]
          else
            data = minion.get_users_authorized_keys_data
            if data.count == 0
              raise('No authorized keys found for users!')
              # TODO:  work out system for pvc-manager access
            end
          end
          connection.write_to_file(:root, data.join("\n"), user_authorized_keys_file_name, user_name, user_name, '0644')
        end
      end

      def user_authorized_keys_file_name
        "/home/#{user_name}/.ssh/authorized_keys"
      end

      def manager_first_bootstrap?
        return false unless has_role?(:manager)
        @manager_first_bootstrap ||= !Pvcglue::Packages::Manager.configuration_exists?
      end
    end
  end
end
