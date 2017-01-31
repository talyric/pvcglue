module Pvcglue
  class Packages
    class Swap < Pvcglue::Packages
      def installed?
        # TODO:  Add swap configuration
        true
      end

      def install!
      end
    end
  end
end
