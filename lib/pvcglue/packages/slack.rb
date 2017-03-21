module Pvcglue
  class Packages
    class Slack < Pvcglue::Packages

      def installed?
        get_minion_state
      end

      def install!
        docs.set_item(
          heading: 'Slack Notifications',
          body: 'Using slacktee.',
          notes: [
            ''
          ],
          cheatsheet: [
            'Test:  echo "Hello World!" | slacktee.sh',
          ],
          references: [
            '[slacktee home]https://github.com/course-hero/slacktee',
            '[slacktee usage]https://github.com/course-hero/slacktee#usage',
            '[Real-time notifications from systemd to Slack]https://www.scaledrone.com/blog/posts/real-time-notifications-from-systemd-to-slack',
          ]
        ) do
          # Persistence
          connection.run!(:root, '', 'curl -o /usr/local/bin/slacktee.sh https://raw.githubusercontent.com/course-hero/slacktee/v1.2.12/slacktee.sh')
          connection.run!(:root, '', 'chmod +x /usr/local/bin/slacktee.sh')
          connection.write_to_file_from_template(user_name, 'slacktee.erb', '.slacktee')
        end

        set_minion_state
      end

      def post_install_check?
        connection.run!(user_name, '', %Q(echo 'Test from #{user_name} on #{minion.machine_name} at #{Time.now.utc.to_s}' | slacktee.sh ) )
        true
      end
    end
  end
end
