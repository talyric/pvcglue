module Pvcglue
  class Packages
    class UnattendedUpgrades < Pvcglue::Packages
      def installed?
        get_minion_state(:installed_unattended_upgrades_at)
      end

      def install!
        connection.write_to_file_from_template(:root, '20auto-upgrades.erb', '/etc/apt/apt.conf.d/20auto-upgrades')
        connection.write_to_file_from_template(:root, '50unattended-upgrades.erb', '/etc/apt/apt.conf.d/50unattended-upgrades')
      end

      def post_install_check?
        connection.run!(:root, '', 'service unattended-upgrades restart')
        set_minion_state(:installed_unattended_upgrades_at, Time.now.utc)
        true
      end
    end
  end
end
