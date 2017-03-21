module Pvcglue
  class Packages
    class SidekiqWorkers < Pvcglue::Packages

      def installed?
        false
      end

      def install!
        Pvcglue::Env.initialize_stage_env
        docs.set_item(
          heading: 'Sidekiq Workers',
          body: 'Set up the worker services.',
          notes: [
            ''
          ],
          cheatsheet: [
            'Enable Service:  systemctl enable sidekiq',
            'Control Service:  systemctl {start,stop,restart} sidekiq',
          ],
          references: [
            '[Example Stuff]https://example/topics/stuff',
            'https://github.com/mperham/sidekiq/wiki/Advanced-Options',
            'https://github.com/mperham/sidekiq/wiki/Using-systemd-to-Manage-Multiple-Sidekiq-Processes',
            'https://github.com/mperham/sidekiq/blob/master/examples/systemd/sidekiq.service',
            'https://github.com/mperham/inspeqtor/wiki/Systemd',
            'http://0pointer.de/public/systemd-man/systemd.exec.html',
            'http://0pointer.de/public/systemd-man/systemd.service.html',
          ]
        ) do
          # Persistence
          connection.write_to_file_from_template(:root, 'sidekiq.service.erb', '/etc/redis/redis.conf')
          connection.run!(:root, '', 'service redis-server restart')

          # Memory management
          connection.run!(:root, '', 'sysctl vm.overcommit_memory=1') # Not sure if this is necessary if doing `sysctl -p`
          connection.write_to_file_from_template(:root, 'sysctl.conf.erb', '/etc/sysctl.conf')
          connection.run!(:root, '', 'sysctl -p')
        end

      end

      def post_install_check?
        true
      end

    end
  end
end
