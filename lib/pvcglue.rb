require "pvcglue/version"
require "thor"
require "pvcglue/configuration"
require "pvcglue/manager"
require "pvcglue/cloud"
require "pvcglue/packages"
require "pvcglue/bootstrap"
require "pvcglue/nodes"
require "pvcglue/env"
require "pvcglue/deploy"
require "pvcglue/capistrano"
require "pvcglue/ssl"
require "pvcglue/db"
require "tilt"

# puts File.join(File.dirname(__FILE__), 'pvcglue', 'packages', '*.rb')

module Pvcglue

  require 'pvcglue/railtie' if defined?(Rails)

  def self.gem_dir
    Gem::Specification.find_by_name('pvcglue').gem_dir
  end

  def self.template_file_name(template)
    File.join(Pvcglue::gem_dir, 'lib', 'pvcglue', 'templates', template)
  end

  def self.render_template(template, file_name = nil)
    data = Tilt.new(Pvcglue.template_file_name(template)).render
    if file_name
      File.write(file_name, data)
    end
    data
  end

  class Version
    def self.version
      VERSION
    end
  end

end
