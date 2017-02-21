module Pvcglue
  class Packages
    class Ruby < Pvcglue::Packages
      def installed?
        connection.run_get_stdout!(user_name, '', 'rvm list strings') =~ /#{Pvcglue.configuration.ruby_version.gsub('.', '\.')}/
      end

      def install!
        connection.run!(user_name, '', "rvm install #{Pvcglue.configuration.ruby_version}")
      end
    end
  end
end
