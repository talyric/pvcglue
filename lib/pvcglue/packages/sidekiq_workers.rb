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
          # stop and disable and remove "old" workers
          services = get_stage_service_file_names
          services.each do |file_name|
            service = File.basename(file_name)
            # TODO:  Stop all the workers, nicely.  :)
            # connection.run!(:root, '', "systemctl stop #{service}")
          end
          services.each do |file_name|
            service = File.basename(file_name)
            connection.run!(:root, '', "systemctl stop #{service}")
            connection.run!(:root, '', "systemctl disable #{service}")
            connection.run!(:root, '', "rm #{file_name}")
          end
          services = get_stage_service_file_names
          raise("Unable to remove services: #{services.join(', ')}") if services.any?

          # create workers
          minion.stage_options.sidekiq_queues.each do |name, options|
            locals = {
              syslog_identifier: service_name(name),
              sidekiq_options: options
            }
            connection.write_to_file_from_template(:root, 'sidekiq.service.erb', service_file_name(name), locals)
            connection.run!(:root, '', 'systemctl daemon-reload')
            connection.run!(:root, '', "systemctl enable #{service_name(name)}")
            connection.run!(:root, '', "systemctl start #{service_name(name)}")
          end
        end

      end

      def get_stage_service_file_names
        data = connection.run_get_stdout(:root, '', "ls #{"#{service_directory}#{worker_base_name}*.service"}")
        data.split("\n")
      end

      def post_install_check?
        # no check can be done if there is no code deployed.
        true
      end

      def worker_base_name # pvc-sidekiq-project-stage-
        "pvc-sidekiq-#{minion.remote_user_name}-"
      end

      def service_directory
        '/lib/systemd/system/'
      end

      def service_file_name(name) # /lib/systemd/system/pvc-sidekiq-project-stage-name.service
        "#{service_directory}#{service_name(name)}#{service_extension}"
      end

      def service_name(name) # pvc-sidekiq-project-stage-name
        "#{worker_base_name}#{name}"
      end

      def service_extension
        '.service'
      end
    end
  end
end
