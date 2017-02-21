module Pvcglue
  class Packages
    class Bundler < Pvcglue::Packages
      def installed?
        connection.run_get_stdout!(user_name, '', 'which bundler') =~ /bundler/
      end

      def install!
        # TODO:  Figure out why this isn't automatic
        connection.run!(user_name, '', 'gem install bundler')
      end
    end
  end
end
