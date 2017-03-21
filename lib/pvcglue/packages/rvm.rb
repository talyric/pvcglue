module Pvcglue
  class Packages
    class Rvm < Pvcglue::Packages
      def installed?
        connection.run_get_stdout!(user_name, '', 'type rvm | head -n 1') =~ /rvm is a function/
      end

      def install!
        connection.write_to_file_from_template(user_name, 'gemrc.erb', "/home/#{user_name}/.gemrc") # sets:  gem: --no-ri --no-rdoc
        connection.write_to_file_from_template(user_name, 'web.bashrc.erb', "/home/#{user_name}/.bashrc")

        connection.run_get_stdout!(user_name, '', 'gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3')
        # Do it again, the first time only sets things up, and does not import the keys
        connection.run!(user_name, '', '\curl -sSL https://get.rvm.io | bash -s stable --with-default-gems=bundler')

        # TODO: set autolibs mode so they are not installed automatically, as the user won't have sudo permissions later.
        # OR create a 'install' user that can sudo...might be easier...
        # Installing required packages: libreadline6-dev, libyaml-dev, libsqlite3-dev, sqlite3, autoconf, libgmp-dev, libgdbm-dev, libncurses5-dev, automake, libtool, bison, pkg-config, libffi-dev...............

        connection.run_get_stdout!(user_name, '', 'rvm requirements')

      end
    end
  end
end
