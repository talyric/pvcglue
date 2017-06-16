module Pvcglue
  class Packages
    class Slack < Pvcglue::Packages

      def installed?
        return true unless minion.project.respond_to?(:slack_webhook_url)
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
            'Test:  echo "Hello World!" | slacktee',
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
          connection.run!(:root, '', 'cp /usr/local/bin/slacktee.sh /usr/local/bin/slacktee')
          connection.write_to_file_from_template(user_name, 'slacktee.erb', '.slacktee')
        end
        connection.run!(user_name, '', %Q(echo 'Build ping from #{user_name} on #{minion.machine_name} at #{Time.now.utc.to_s}' | slacktee.sh ))

        set_minion_state
      end

    end
  end
end
