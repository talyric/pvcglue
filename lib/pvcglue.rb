require "pvcglue/version"
require "pvcglue/configuration"
require "pvcglue/manager"
require "pvcglue/cloud"
require "pvcglue/packages"
require "pvcglue/bootstrap"

# puts File.join(File.dirname(__FILE__), 'pvcglue', 'packages', '*.rb')

module Pvcglue

  def self.gem_dir
    Gem::Specification.find_by_name('pvcglue').gem_dir
  end

  class Version
    def self.version
      VERSION
    end
  end

end
