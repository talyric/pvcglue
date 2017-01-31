module Pvcglue
  class Packages
    class SshKeyCheck < Pvcglue::Packages
      def installed?
        # Add key to known_hosts file to prevent needing interactive prompt
        minion.connection.ssh(:root, '-o strictHostKeyChecking=no', 'echo')
        true
      end
    end
  end
end
