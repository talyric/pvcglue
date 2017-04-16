module Pvcglue
  class Packages

    def self.apply(minion, options = {})
      package = new(minion, options)
      unless package.run
        raise package.full_error_message if package.errors?
      end
    end

    attr_accessor :errors
    attr_accessor :options
    attr_accessor :post_install_max_retry_seconds
    attr_accessor :post_install_max_retry_count
    attr_accessor :post_install_retry_delay_seconds

    def initialize(minion, options = {})
      @minion = minion
      @options = options
      @errors = []
    end

    def docs
      Pvcglue.docs
    end

    def errors?
      errors.size > 0
    end

    def full_error_message
      errors.join('.  ')
    end

    def minion
      @minion
    end

    def user_name
      @minion.remote_user_name
    end

    def run
      begin
        Pvcglue.logger_package_description = self.class.name
        unless installed?
          install!
          if post_install_check_with_retry?
            post_install!
          else
            # TODO:  Better error message

            errors << 'Install failed post install check.'
            Pvcglue.logger.error { full_error_message }
            return false
          end
        end
      ensure
        Pvcglue.logger_package_description = ''
      end
      true
    end

    def installed?
      false
    end

    def install!
      false
    end

    def post_install_check?
      # override to do a different (more time consuming/more detailed) check
      installed?
    end

    def post_install_retry(max_tries, delay_seconds = 0, max_seconds = 30)
      self.post_install_max_retry_seconds = max_seconds
      self.post_install_retry_delay_seconds = delay_seconds
      self.post_install_max_retry_count = max_tries
    end

    def post_install_check_with_retry?
      self.post_install_max_retry_seconds = 0.0
      self.post_install_retry_delay_seconds = 0.0
      self.post_install_max_retry_count = 1
      started_at = Time.now.utc.to_f
      tries = 0
      begin
        return true if post_install_check?
        tries += 1
        Pvcglue.logger.debug('Failed post install check, retrying...')
        sleep(post_install_retry_delay_seconds)
      end until tries >= post_install_max_retry_count || Time.now.utc.to_f - started_at > post_install_max_retry_seconds
      false
    end

    def post_install!

    end

    def has_role?(roles)
      minion.has_role?(roles)
    end

    def has_roles?(roles)
      minion.has_role?(roles)
    end

    def connection
      @minion.connection
    end

    def minion_state_file_name
      ".minion_state_#{user_name}.toml"
    end

    def load_state_data
      if connection.file_exists?(:root, minion_state_file_name)
        data = connection.read_from_file(:root, minion_state_file_name)
      else
        data = ''
      end
      # puts data
      connection.minion_state_data = TOML.parse(data, symbolize_keys: true)
    end


    def get_minion_state_data
      unless connection.minion_state_data
        if Pvcglue.reset_minion_state?
          Pvcglue.logger.warn('Minion state data reset.')
          connection.minion_state_data = {}
        else
          load_state_data
        end
      end
    end

    def get_minion_state(key = nil)
      key = get_minion_state_key(key)
      get_minion_state_data
      connection.minion_state_data[key]
    end

    def get_minion_state_key(key)
      key || self.class.name.downcase.gsub(':', '_').to_sym
    end

    def set_minion_state(key = nil, value = nil)
      value ||= Time.now.utc
      key = get_minion_state_key(key)
      get_minion_state_data
      connection.minion_state_data[key] = value
      connection.write_to_file(:root, TOML.dump(connection.minion_state_data), minion_state_file_name)
    end


    # def self.apply(package, context, nodes, user = 'deploy', package_filter = nil)
    #   # puts nodes.inspect
    #   orca_suite = OrcaSuite.init(package_filter)
    #   nodes.each do |node, data|
    #     old_current_node = ::Pvcglue.cloud.current_node_without_nil_check # this is being called recursively, so keep the original data...kinda a hack for now
    #     orca_node = ::Orca::Node.new(node, data[:public_ip], {user: user, port: Pvcglue.cloud.port_in_context(context)})
    #     # puts "#"*800
    #     # puts orca_node.name
    #     # puts package.to_s
    #     # puts "^"*80
    #     ::Pvcglue.cloud.current_node = {node => data}
    #     tries = 3
    #     begin
    #       begin
    #         # puts "="*800
    #         # puts orca_node.name
    #         # puts package.to_s
    #         # puts "^"*80
    #         orca_suite.run(orca_node.name, package.to_s, :apply)
    #       ensure
    #         # puts "-"*800
    #         # puts orca_node.name
    #         # puts package.to_s
    #         # puts "^"*80
    #         ::Pvcglue.cloud.current_node = old_current_node
    #
    #         # ::Pvcglue.cloud.current_node = nil
    #         ::Pvcglue.cloud.current_hostname = nil
    #       end
    #     rescue Exception => e
    #       tries -= 1
    #       if tries > 0
    #         puts "\n"*10
    #         puts "*"*80
    #         puts "ERROR, retrying..."
    #         puts e.message
    #         puts "*"*80
    #         retry
    #       else
    #         puts "\n"*10
    #         puts "*"*80
    #         puts "ERROR, not retrying, fatal."
    #         puts e.message
    #         e.backtrace.each { |line| puts line }
    #         puts e.message
    #         puts node.inspect
    #         puts data.inspect
    #         puts "*"*80
    #       end
    #     end
    #   end
    # end
  end

  # class OrcaSuite
  #
  #   def self.init(package_filter)
  #     ::Orca.verbose(package_filter != 'manager') # show details for all packages except manager, for now
  #
  #     # Load orca extensions
  #     orca_file = File.join(File.dirname(__FILE__), 'all_the_things.rb')
  #     ENV['ORCA_FILE'] = orca_file
  #     suite = ::Orca::Suite.new
  #     suite.load_file(orca_file)
  #     packages_loaded = []
  #
  #     Dir[File.join(Pvcglue::gem_dir, 'lib', 'pvcglue', 'packages', '*.rb')].each do |file|
  #       # package filter is used to load the manager package by itself when stage is not specified
  #       next if package_filter && package_filter != File.basename(file, ".rb")
  #       begin
  #         suite.load_file(file)
  #       rescue Exception => e
  #         puts "Error loading #{file}:  #{e.message}"
  #         raise
  #       end
  #       packages_loaded << File.basename(file, ".rb")
  #     end
  #     puts "Packages loaded: #{packages_loaded.sort.join(' ')}."
  #     suite
  #   end
  # end

end
