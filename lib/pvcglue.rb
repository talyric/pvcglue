require "pvcglue/version"

module Pvcglue
  class Version
    def self.version
      VERSION
    end
  end

  class Bootstrap
    def self.bootstrap(stage)
      puts "This is where it should bootstrap #{stage}.  :)"
    end
  end
end
