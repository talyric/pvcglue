# Based on http://robots.thoughtbot.com/mygem-configure-block
# and https://github.com/thoughtbot/clearance/blob/master/lib/clearance/configuration.rb

module Pvcglue
  class Configuration
    attr_accessor :cloud_master

    def initialize
      @cloud_master = '<error>'
    end
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configuration=(config)
    @configuration = config
  end

  def self.configure
    yield configuration
  end
end