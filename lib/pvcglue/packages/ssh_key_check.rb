module Pvcglue
  class Packages
    class SshKeyCheck < Pvcglue::Packages
      def installed?
        docs.level_2('Status')
        # This has the side effect of adding the server to known_hosts file, to prevent needing interactive prompt
        docs.set_item(
          heading: 'Verify Connection',
          body: 'Connect to the machine and wait until it''s ready (with automatic retry).  Also add the machine to the `known_hosts` file, to prevent an interactive prompt'
        ) do
          connection.ssh_retry_wait(:root, '-o strictHostKeyChecking=no', 'echo', 30, 1)
        end
        true
      end
    end
  end
end
