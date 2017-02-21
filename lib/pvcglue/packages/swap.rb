module Pvcglue
  class Packages
    class Swap < Pvcglue::Packages
      def installed?

        # sudo("cat /etc/fstab") =~ /\/swapfile/
        true
      end

      def install!
      end
    end
  end
end
