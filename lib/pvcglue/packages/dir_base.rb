module Pvcglue
  class Packages
    class DirBase < Pvcglue::Packages
      def installed?
        result = connection.run_get_stdout(user_name, '', "stat --format=%U:%G:%a #{Pvcglue.cloud.web_app_base_dir}").strip
        result == "#{user_name}:#{user_name}:2755"
      end

      def install!
        dir = Pvcglue.cloud.web_app_base_dir
        # used following as a guide for next line: http://capistranorb.com/documentation/getting-started/authentication-and-authorisation/
        connection.run!(user_name, '', "mkdir -p #{dir} && chown #{user_name}:#{user_name} #{dir} && chmod 0755 #{dir} && umask 0002 && chmod g+s #{dir}")
      end
    end
  end
end
