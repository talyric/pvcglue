require 'pvcglue/version'
require 'thor'
require 'pvcglue/configuration'
require 'pvcglue/manager'
require 'pvcglue/cloud'
require 'pvcglue/packages'
Dir[File.dirname(__FILE__) + '/pvcglue/packages/*.rb'].each { |file| require file }
Dir[File.dirname(__FILE__) + '/pvcglue/cloud_providers/*.rb'].each { |file| require file }
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
require 'pvcglue/docs'
require 'tilt'
require 'awesome_print'
require 'hashie'
require 'pvcglue/custom_hashie'
require 'pvcglue/minion'
require 'droplet_kit'
# require 'pvcglue/digital_ocean'
require 'logger'
require 'pvcglue/connection'
require 'paint'
require 'pry'
require 'net/http'
require 'byebug'


# require 'thor'
# require 'tilt'
# require 'awesome_print'
# require 'hashie'
# require 'pvcglue/custom_hashie'
# require 'logger'
# Dir[File.dirname(__FILE__) + '/pvcglue/*.rb'].each { |file| require file unless File.basename(file) == 'cli.rb' }
# require 'pvcglue/cli'
# Dir[File.dirname(__FILE__) + '/pvcglue/packages/*.rb'].each { |file| require file }
# Dir[File.dirname(__FILE__) + '/pvcglue/cloud_providers/*.rb'].each { |file| require file }
# require 'droplet_kit'
# require 'paint'
# require 'pry'
# require 'net/http'
# require 'byebug'

# puts File.join(File.dirname(__FILE__), 'pvcglue', 'packages', '*.rb')
# pvc manager bootstrap --cloud_manager_override=local_cloud.pvcglue.toml --save_before_upload=save --verbose


# TODO:  Set up a maintenance mode page and command to allow the message to be changed without a redeploy, like if Amazon S3 goes down...
#
module Pvcglue
  # def self.reset!
  #   ap Pvcglue.instance_variables
  #   ap Pvcglue.class_variables
  #
  #   raise("Now working!")
  #   Pvcglue.constants.select { |c| Pvcglue.const_get(c).is_a? Class }.each do |pvc_class|
  #     pvc_class.instance_variables.each do |var|
  #       pvc_class.remove_instance_variable(var)
  #     end
  #
  #     if pvc_class.respond_to?(:class_variables)
  #       pvc_class.class_variables.each do |var|
  #         pvc_class.remove_class_variable(var)
  #       end
  #     end
  #   end
  #
  #   Pvcglue::Packages.constants.select { |c| Pvcglue::Packages.const_get(c).is_a? Class }.each do |pvc_class|
  #     pvc_class.instance_variables.each do |var|
  #       pvc_class.remove_instance_variable(var)
  #     end
  #     if pvc_class.respond_to?(:class_variables)
  #       pvc_class.class_variables.each do |var|
  #         pvc_class.remove_class_variable(var)
  #       end
  #     end
  #   end
  #
  #   self.instance_variables.each do |var|
  #     # ap var.inspect
  #     # ap self.instance_variable_get(var)
  #     # self.instance_variable_set var, nil
  #     self.remove_instance_variable(var)
  #     # ap self.instance_variable_get(var)
  #
  #   end
  # end

  mattr_accessor :command_line_options do
    {}
  end

  mattr_accessor :logger do

    logger = Logger.new(STDOUT)
    # DEBUG < INFO < WARN < ERROR < FATAL < UNKNOWN
    if ARGV.detect { |arg| arg.downcase == '--debug' || arg.downcase == '--verbose' }
      logger.level = Logger::DEBUG
    elsif ARGV.detect { |arg| arg.downcase == '--quiet' }
      logger.level = Logger::WARN
    elsif ARGV.detect { |arg| arg.downcase == '--info' }
      logger.level = Logger::INFO
    else
      logger.level = Logger::INFO
    end

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

  mattr_accessor :docs do
    Pvcglue::Docs.new(!!ARGV.detect { |arg| arg.downcase == '--docs' })
  end

  def self.verbose?
    return if @filtering_verbose
    if Pvcglue.command_line_options[:verbose]
      puts yield
    end
  end

  def self.filter_verbose
    @filtering_verbose = true
    begin
      yield
    ensure
      @filtering_verbose = false
    end
  end

  def self.reset_minion_state?
    !!Pvcglue.command_line_options[:rebuild]
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
      raise("Error:  #{$?}")
    end
    true
  end

  def self.system_get_stdout(cmd)
    Pvcglue.logger.debug { cmd }
    result = `#{cmd}`
    Pvcglue.verbose? { result }
    Pvcglue.logger.debug { "exit_code=#{$?.to_i}" }
    result
  end

  class Version
    def self.version
      VERSION
    end
  end

end
