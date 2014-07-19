require 'toml'
# Inspired by http://robots.thoughtbot.com/mygem-configure-block
# and https://github.com/thoughtbot/clearance/blob/master/lib/clearance/configuration.rb

# Example for '~/.pvcglue.toml':
#     cloud_manager = "nnn.nnn.nnn.nnn"

module Pvcglue
  class Configuration < Thor

    attr_accessor :cloud_manager
    attr_accessor :cloud_name
    attr_accessor :application_name
    attr_accessor :context

    def self.file_name
      ENV['PVCGLUE_FILE_NAME'] || '.pvcglue.toml'
    end

    def self.env_prefix
      ENV['PVCGLUE_ENV_PREFIX'] || 'PVCGLUE'
    end


    # silence Thor warnings, as these are not Thor commands.  (But we still need 'say' and 'ask' and friends.)
    no_commands do

      def initialize
        #ENV["PVCGLUE_#{'application_name'.upcase}"] = 'override'
        init(:cloud_manager) || configure_manager
        raise(Thor::Error, "The manager has not been configured.  :(") if cloud_manager.nil?
        init_except_manager
      end

      def init_except_manager
        init(:cloud_name, 'cluster_one')
        init(:application_name, find_app_name)
      end

      def configure_manager
        say('The manager has not been configured.')
        manager = ask('What is the IP address or host name of the manager?')
        default = !no?('Will this be the default manager? (Y/n)')
        file_name = default ? user_file_name : project_file_name
        File.write(file_name, %(cloud_manager = "#{manager}"\n))
        say("Manager written to #{file_name}.")

        @conf = nil # clear cache
        init(:cloud_manager)
        init_except_manager
        clear_cloud_cache
      end

      def init(option, default=nil)
        # ENV first, then pvcglue.toml (checking current working directory first, then in user home '~'), then default
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
          data = TOML.load_file(file_name)
          #puts data.inspect
          @conf.merge!(data)
        end
      end

      def get_conf(option)
        unless @conf
          @conf = {}
          merge_into_conf(user_file_name)
          merge_into_conf(project_file_name)
        end
        @conf[option.to_s]
      end

      def project_file_name
        File.join(application_dir, self.class.file_name)
      end

      def user_file_name
        File.join(Dir.home, self.class.file_name)
      end

      def find_app_name
        # try rack file...anyone know a better way, without loading Rails?
        rack_up = File.join(application_dir, 'config.ru')
        $1.downcase if File.exists?(rack_up) && File.read(rack_up) =~ /^run (.*)::/
      end

      def options
        Hash[instance_variables.map { |name| [name.to_s[1..-1].to_sym, instance_variable_get(name)] }].reject { |k| k == :conf }
      end

      def tmp_dir
        File.join(application_dir, 'tmp')
      end

      def cloud_cache_file_name
        # Just in case the Rails project hasn't yet been run, make sure the tmp
        # dir exists.
        Dir.mkdir(tmp_dir) unless Dir.exist?(tmp_dir)

        File.join(tmp_dir, "pvcglue_#{cloud_manager}_#{cloud_name}_#{application_name}_cache.toml")
      end

      def clear_cloud_cache
        File.delete(cloud_cache_file_name) if File.exists?(cloud_cache_file_name)
      end

      def application_dir
        Dir.pwd
      end

      def app_maintenance_files_dir
        File.join(application_dir, 'public', 'maintenance')
      end

      def ruby_version_file_name
        File.join(application_dir,'.ruby-version')
      end

      def ruby_version
        File.read(ruby_version_file_name).strip
      end

      def web_app_base_dir
        '/sites'
      end
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
