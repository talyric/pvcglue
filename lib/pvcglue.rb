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

  def self.template_file_name(template)
    File.join(Pvcglue::gem_dir, 'lib', 'pvcglue', 'templates', template)
  end

  class Version
    def self.version
      VERSION
    end
  end

end
