require 'pvcglue/version'
require 'thor'
require 'pvcglue/configuration'
require 'pvcglue/manager'
require 'pvcglue/cloud'
require 'pvcglue/packages'
Dir[File.dirname(__FILE__) + '/pvcglue/packages/*.rb'].each { |file| require file }
require 'pvcglue/bootstrap'
require 'pvcglue/nodes'
require 'pvcglue/stack'
require 'pvcglue/env'
require 'pvcglue/deploy'
require 'pvcglue/capistrano'
require 'pvcglue/ssl'
require 'pvcglue/db'
require 'pvcglue/toml_pvc_dumper'
require 'pvcglue/local'
require 'pvcglue/monit'
require 'pvcglue/pvcify'
require 'tilt'
require 'awesome_print'
require 'hashie'
require 'pvcglue/custom_hashie'
require 'pvcglue/minion'
require 'droplet_kit'
require 'pvcglue/digital_ocean'
require 'logger'
require 'pvcglue/connection'
require 'paint'

# puts File.join(File.dirname(__FILE__), 'pvcglue', 'packages', '*.rb')
# pvc manager bootstrap --cloud_manager_override=local_cloud.pvcglue.toml --save_before_upload=save --verbose

module Pvcglue
  mattr_accessor :command_line_options do
    {}
  end

  mattr_accessor :logger do

    logger = Logger.new(STDOUT)
    # logger.level = Logger::INFO # DEBUG < INFO < WARN < ERROR < FATAL < UNKNOWN
    logger.level = Logger::DEBUG # DEBUG < INFO < WARN < ERROR < FATAL < UNKNOWN
    # logger.warn('Starting up...')
    logger.formatter = proc do |severity, datetime, progname, msg|
      minion_name = Pvcglue.logger_current_minion.try(:machine_name)
      minion_name = "/#{minion_name}" if minion_name
      description = Pvcglue.logger_package_description
      if description
        description = description.split('::').last || description
        description = "/#{description.downcase}"
      end
      foreground = nil
      # background = 'black'
      background = nil
      case severity[0..0]
        when 'E'
          foreground = 'red'
        when 'W'
          # foreground = 'black'
          # background = 'yellow'
          foreground = 'yellow'
        when 'I'
          foreground = 'purple'
        when 'D'
          foreground = 'cyan'
        else
          foreground = 'black'
          background = 'red'
      end
      # case severity[0..0]
      #    when 'E'
      #      color = :redish
      #    when 'W'
      #      color = :yellowish
      #    when 'I'
      #      color = :purpleish
      #    when 'D'
      #      color = :cyanish
      #    else
      #      color = :yellowish
      #  end
      #  "#{severity[0..0]} [#{datetime.strftime('%H:%M:%S')}#{minion_name}#{description}]  #{msg}\n".send(color)
      Paint["#{severity[0..0]} [#{datetime.strftime('%H:%M:%S')}#{minion_name}#{description}]  #{msg}\n", foreground, background]
    end
    logger
  end
  mattr_accessor :logger_package_description
  mattr_accessor :logger_current_minion

  def self.verbose?
    if Pvcglue.command_line_options[:verbose]
      puts yield
    end
  end

  def self.reset_minion_state?
    !!Pvcglue.command_line_options[:reset_minion_state]
  end

  def self.gem_dir
    Gem::Specification.find_by_name('pvcglue').gem_dir
  end

  def self.template_file_name(template)
    File.join(Pvcglue::gem_dir, 'lib', 'pvcglue', 'templates', template)
  end

  def self.render_template(template, file_name = nil)
    # puts '-'*80
    # puts "---> render_template(template=#{template}, file_name=#{file_name}"
    data = Tilt.new(Pvcglue.template_file_name(template)).render
    if file_name
      File.write(file_name, data)
    end
    data
  end

  def self.run_remote(host, port, user, cmd)
    cmd = "ssh -p #{port} #{user}@#{host} '#{cmd}'"
    # puts "Running `#{cmd}`"

    unless system cmd
      raise(Thor::Error, "Error:  #{$?}")
    end
    true
  end

  class Version
    def self.version
      VERSION
    end
  end

end
