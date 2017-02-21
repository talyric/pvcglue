module Pvcglue
  class Packages
    class SshKeyCheck < Pvcglue::Packages
      def installed?
        # This has the side effect of adding the server to known_hosts file, to prevent needing interactive prompt
        connection.ssh_retry_wait(:root, '-o strictHostKeyChecking=no', 'echo', 30, 1)
        true
      end
    end
  end
end
