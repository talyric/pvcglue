module Pvcglue
  class Packages
    class Worker < Pvcglue::Packages

      def installed?
        false
      end

      def install!
        Pvcglue::Packages::DirBase.apply(minion)
        Pvcglue::Packages::DirShared.apply(minion)
        Pvcglue::Packages::Rvm.apply(minion)
        Pvcglue::Packages::Ruby.apply(minion)
        Pvcglue::Packages::Bundler.apply(minion)
        Pvcglue::Packages::Secrets.apply(minion)
        Pvcglue::Packages::SidekiqWorkers.apply(minion)
      end

      def post_install_check?
        true
      end

    end
  end
end
