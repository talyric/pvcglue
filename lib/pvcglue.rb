require "pvcglue/version"
require "pvcglue/configuration"
require "pvcglue/manager"
require "pvcglue/cloud"
require "pvcglue/packages"

puts File.join(File.dirname(__FILE__), 'pvcglue', 'packages', '*.rb')

module Pvcglue

  def self.gem_dir
    Gem::Specification.find_by_name('pvcglue').gem_dir
  end

  class Version
    def self.version
      VERSION
    end
  end

  class Bootstrap
    def self.run(stage)
      puts "This is where it should bootstrap #{stage}.  :)"
    end
  end

end
