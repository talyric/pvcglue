require 'json'
# Inspired by http://robots.thoughtbot.com/mygem-configure-block
# and https://github.com/thoughtbot/clearance/blob/master/lib/clearance/configuration.rb

module Pvcglue
  class Configuration
    attr_accessor :cloud_manager
    attr_accessor :cloud_name
    attr_accessor :application_name

    def self.file_name
      ENV['PVCGLUE_FILE_NAME'] || '.pvcglue.json'
    end

    def self.env_prefix
      ENV['PVCGLUE_ENV_PREFIX'] || 'PVCGLUE'
    end

    def initialize
      #ENV["PVCGLUE_#{'application_name'.upcase}"] = 'override'
      init(:cloud_manager, '<required>')
      init(:cloud_name, 'cluster_one')
      init(:application_name, find_app_name)
    end

    def init(option, default=nil)
      # ENV first, then pvcglue.json (checking current working directory first, then in user home '~'), then default
      # NOTE:  In the context of Rails, a standard initializer can also be used, and will override all settings here, but that should not really apply for 'pvcglue'
      # /config/initializers/pvcglue.rb:
      # Pvcglue.configure do |config|
      #   config.cloud_manager = '192.168.0.1'
      # end
      value = ENV["#{self.class.env_prefix}_#{option.upcase}"] || get_conf(option) || default
      #puts "Setting #{option}=#{value}"
      instance_variable_set("@#{option}", value)
    end

    def merge_into_conf(file_name)
      #puts "*"*80
      #puts file_name
      #puts File.exists?(file_name).inspect
      if File.exists?(file_name)
        data = JSON.parse(File.read(file_name))
        #puts data.inspect
        @conf.merge!(data)
      end
    end

    def get_conf(option)
      unless @conf
        @conf = {}
        merge_into_conf(File.join(Dir.home, self.class.file_name))
        merge_into_conf(File.join(Dir.pwd, self.class.file_name))
      end
      @conf[option.to_s]
    end

    def find_app_name
      # try rack file...anyone know a better way, without loading Rails?
      rack_up = File.join(Dir.pwd, 'config.ru')
      $1.downcase if File.exists?(rack_up) && File.read(rack_up) =~ /^run (.*)::/
    end

    def options
      Hash[instance_variables.map { |name| [name.to_s[1..-1].to_sym, instance_variable_get(name)] }].reject { |k| k == :conf }
    end

  end

  # --------------------------------------------------------------------------------------------------------------------

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