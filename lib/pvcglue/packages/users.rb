module Pvcglue
  class Packages
    class Users < Pvcglue::Packages
      def installed?
        result = connection.run_get_stdout(:root, '', "getent passwd #{user_name} && groups #{user_name}")
        result =~ /^#{user_name}:/ && result =~ /#{user_name} sudo/
      end

      def install!
        # connection.run!(:root, '', 'mkdir -p ~/.pvc && chmod 600 ~/.pvc')  # TODO:  Still needed?
        # connection.run!(:root, '', "useradd -d /home/#{user_name} -G sudo -m -U #{user_name} && usermod -s /bin/bash #{user_name}")

        connection.run!(:root, '', "useradd -d /home/#{user_name} -G sudo -m -U #{user_name}")
        connection.run!(:root, '', "usermod -s /bin/bash #{user_name}")
        # TODO:  Lock down the sudo permissions to just let the user deploy
        connection.run!(:root, '', "echo '#{user_name} ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers")
      end
    end
  end
end
