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
            'Enable Service:  systemctl enable <name> # Without ".service"',
            'Control Service:  systemctl {start,stop,restart} <name> # Without ".service"',
            'List Services:  systemctl | grep pvc',
            'Logs (all workers):  journalctl -u pvc-sidekiq-*',
          ],
          references: [
            '[Example Stuff]https://example/topics/stuff',
            'https://github.com/mperham/sidekiq/wiki/Advanced-Options',
            'https://github.com/mperham/sidekiq/wiki/Using-systemd-to-Manage-Multiple-Sidekiq-Processes',
            'https://github.com/mperham/sidekiq/blob/master/examples/systemd/sidekiq.service',
            'https://github.com/mperham/inspeqtor/wiki/Systemd',
            'http://0pointer.de/public/systemd-man/systemd.exec.html',
            'http://0pointer.de/public/systemd-man/systemd.service.html',
            'https://www.freedesktop.org/software/systemd/man/systemd.service.html#Restart=',
          ]
        ) do
          Pvcglue.logger.debug {'Stopping, disabling and removing "old" workers'}
          old_services = stage_service_file_names
          old_services.each do |file_name|
            service = File.basename(file_name)
            Pvcglue.logger.debug {"Quieting #{service}"}
            connection.run?(:root, '', "sudo systemctl kill -s USR1 --kill-who=main #{service}")
          end

          # TODO:  Wait for workers to be quiet?

          old_services.each do |file_name|
            service = File.basename(file_name)
            Pvcglue.logger.debug {"Stopping, disabling and removing #{service}"}
            connection.run!(:root, '', "systemctl stop #{service}")
            connection.run!(:root, '', "systemctl disable #{service}")
            connection.run!(:root, '', "rm #{file_name}")
          end
          old_services = stage_service_file_names
          raise("Unable to remove services: #{old_services.join(', ')}") if old_services.any?

          Pvcglue.logger.debug {'New workers'}
          if minion.stage_options.sidekiq_queues
            minion.stage_options.sidekiq_queues.each do |name, options|
              service = minion.sidekiq_service_name(name)
              Pvcglue.logger.debug {"Creating, enabling and starting #{service}"}
              locals = {
                syslog_identifier: service,
                sidekiq_options: options
              }
              connection.write_to_file_from_template(:root, 'sidekiq.service.erb', minion.sidekiq_service_file_name(name), locals)
              connection.run!(:root, '', 'systemctl daemon-reload')
              connection.run!(:root, '', "systemctl enable #{service}")
              connection.run!(:root, '', "systemctl start #{service}")
            end
          else
            Pvcglue.logger.warn {'No workers configured'}
          end

        end

      end

      def post_install_check?
        # no check can be done if there is no code deployed.
        true
      end

      def stage_service_file_names
        cmd = "ls #{"#{Pvcglue.cloud.service_directory}#{minion.sidekiq_worker_base_name}*#{Pvcglue.cloud.service_extension}"}"
        data = connection.run_get_stdout(:root, '', cmd)
        data.split("\n")
      end

    end
  end
end
