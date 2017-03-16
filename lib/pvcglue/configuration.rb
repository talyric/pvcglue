require 'toml'
# Inspired by http://robots.thoughtbot.com/mygem-configure-block
# and https://github.com/thoughtbot/clearance/blob/master/lib/clearance/configuration.rb

# Example for '~/.pvcglue.toml':
#     cloud_manager = "nnn.nnn.nnn.nnn"

module Pvcglue
  class Configuration < Thor

    attr_accessor :cloud_manager
    attr_accessor :local_cloud_manager
    attr_accessor :cloud_name
    attr_accessor :application_name
    attr_accessor :context

    def self.file_name
      ENV['PVCGLUE_FILE_NAME'] || '.pvcglue.toml'
    end

    def self.env_prefix
      ENV['PVCGLUE_ENV_PREFIX'] || 'PVCGLUE'
    end

    def self.project_file_name
      File.join(self.application_dir, file_name)
    end

    def self.application_dir
      Dir.pwd
    end

    # silence Thor warnings, as these are not Thor commands.  (But we still need 'say' and 'ask' and friends.)
    no_commands do

      def initialize
        if Pvcglue::Manager.local_mode?
          init(:local_cloud_manager)
          @cloud_manager = @local_cloud_manager
        else
          unless init(:cloud_manager)
            say('The manager has not been configured.')
            configure_manager
          end
        end

        # raise(Thor::Error, "The manager has not been configured.  :(") if cloud_manager.nil?
        raise("The manager has not been configured.  :(") if cloud_manager.nil?
        init_except_manager
      end

      def init_except_manager
        # TODO:  This 'caches' the file name and then if local_mode is enabled, it still uses the 'cached' file name...Must Fix!
        if Pvcglue::Manager.local_mode?
          @cloud_name = 'local_cloud'
        else
          init(:cloud_name, 'cluster_one')
        end
        init(:application_name, find_app_name)
      end

      def configure_manager
        byebug
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
        self.class.project_file_name
      end

      def user_file_name
        File.join(Dir.home, self.class.file_name)
      end

      # Thanks to http://stackoverflow.com/a/1509957/444774
      def underscore(camel_cased_word)
        camel_cased_word.to_s.gsub(/::/, '/').
            gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
            gsub(/([a-z\d])([A-Z])/, '\1_\2').
            tr("-", "_").
            downcase
      end

      def find_app_name
        # TODO:  Just use something like `rails runner 'Rails.application.class.parent'` and then cache it to a temporary file
        # try known files...anyone know a better way, without loading Rails?
        rack_up = File.join(application_dir, 'config.ru')
        app_name = underscore($1) if File.exists?(rack_up) && File.read(rack_up) =~ /^run (.*)::/
        unless app_name
          file_name = File.join(application_dir, 'config', 'application.rb')
          app_name = underscore($1) if File.exists?(file_name) && File.read(file_name) =~ /^module (.*)/
        end
        app_name
      end

      def options
        Hash[instance_variables.map { |name| [name.to_s[1..-1].to_sym, instance_variable_get(name)] }].reject { |k| k == :conf }
      end

      def tmp_dir
        File.join(application_dir, 'tmp')
      end

      def pvcglue_tmp_dir
        File.join(tmp_dir, 'pvcglue')
      end

      def template_override_dir
        File.join(application_dir, 'config', 'pvcglue', 'templates')
      end

      def cloud_cache_file_name
        # Just in case the Rails project hasn't yet been run, make sure the tmp
        # dir exists.
        Dir.mkdir(pvcglue_tmp_dir) unless Dir.exist?(pvcglue_tmp_dir)

        File.join(pvcglue_tmp_dir, "pvcglue_#{cloud_manager}_#{cloud_name}_#{application_name}_cache.toml")
      end

      def clear_cloud_cache
        File.delete(cloud_cache_file_name) if File.exists?(cloud_cache_file_name)
      end

      def application_dir
        self.class.application_dir
      end

      def app_maintenance_files_dir
        File.join(application_dir, 'public', 'maintenance')
      end

      def ruby_version_file_name
        File.join(application_dir, '.ruby-version')
      end

      def gemfile_file_name
        File.join(application_dir, 'Gemfile')
      end

      def ruby_version
        File.read(ruby_version_file_name).strip
      end

      def rails_version
        @rails_version ||= begin
          `bundle exec rails -v`.sub('Rails ', '').strip
        end
      end

      def rails_version_major
        rails_version.split('.').first
      end

      def rails_bin_dir
        if rails_version_major.to_i >= 4
          'bin'
        else
          'script'
        end
      end

      # def web_app_base_dir
      #   # '/sites'
      #   '~/www'
      #   # "/home/#{user_name}/.ssh"
      # end

      def build_log_extra_dir
        @build_log_extra_dir ||= begin
          option = Pvcglue.command_line_options[:save_before_upload]
          if option != 'save_before_upload'
            dir_name = option
          else
            dir_name = Time.now.strftime('%Y-%m-%d-%H%M%S')
          end
          result = File.join(pvcglue_tmp_dir, dir_name)
          `mkdir -p '#{result}'`
          raise $?.inspect unless $?.exitstatus == 0
          result
        end
      end

      def build_log_extra_filename(minion, user, remote_filename)
        # local_filename = File.basename(remote_filename)
        relative = remote_filename.sub(Pvcglue.cloud.web_app_base_dir, '/project')
        local_filename = relative.sub(/\A\//, '').gsub(/\//, '__')
        # local_filename = File.basename(remote_filename)
        versioned_filename(File.join(build_log_extra_dir, "#{minion.machine_name}--#{user}--#{local_filename}"))
      end

      # TODO:  Refactor to a utilities module or something
      def versioned_filename(base, first_suffix='.00')
        suffix = nil
        filename = base
        while File.exists?(filename)
          suffix = (suffix ? suffix.succ : first_suffix)
          filename = base + suffix
        end
        return filename
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
