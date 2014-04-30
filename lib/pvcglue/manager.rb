require 'pp'

module Pvcglue
  class Manager < Thor

    desc "bootstrap", "bootstrap"

    def bootstrap
      Pvcglue::Packages.apply('bootstrap-manager'.to_sym, self.class.manager_node, 'root', 'manager')
    end

    desc "push", "push"

    def push
      Pvcglue::Packages.apply('manager-push'.to_sym, self.class.manager_node, 'pvcglue', 'manager')
      self.class.clear_cloud_data_cache
    end

    desc "pull", "pull"

    def pull
      Pvcglue::Packages.apply('manager-pull'.to_sym, self.class.manager_node, 'pvcglue', 'manager')
      self.class.clear_cloud_data_cache
    end

    desc "show", "show"

    def show
      self.class.initialize_cloud_data
      pp Pvcglue.cloud.data
    end

    desc "configure", "configure"

    def configure
      Pvcglue.configuration.configure_manager
    end

    # ------------------------------------------------------------------------------------------------------------------

    def self.initialize_cloud_data
      unless read_cached_cloud_data
        Pvcglue::Packages.apply('manager-get-config'.to_sym, manager_node, 'pvcglue', 'manager')
        # Pvcglue::Packages.apply('manager-get-config'.to_sym, manager_node, 'pvcglue') # Can not use package as it causes infinite recursion, we'll just do it manually
        data = `ssh pvcglue@#{manager_node[:manager][:public_ip]} "cat #{Pvcglue::Manager.manager_file_name}"`
        # puts "*"*80
        # puts data
        # puts "*"*80
        if data.empty?
          raise(Thor::Error, "Remote manager file not found (or empty):  #{::Pvcglue::Manager.manager_file_name}")
        else
          ::Pvcglue.cloud.data = TOML.parse(data)
        end
        write_cloud_data_cache
      end
    end

    def self.write_cloud_data_cache
      File.write(Pvcglue.configuration.cloud_cache_file_name, TOML.dump(Pvcglue.cloud.data))
    end

    def self.read_cached_cloud_data
      # TODO:  Expire cache after given interval
      if File.exists?(Pvcglue.configuration.cloud_cache_file_name)
        data = File.read(Pvcglue.configuration.cloud_cache_file_name)
        Pvcglue.cloud.data = TOML.parse(data)
        return true
      end
      false
    end

    def self.clear_cloud_data_cache
      Pvcglue.configuration.clear_cloud_cache
    end

    def self.manager_node
      {manager: {public_ip: Pvcglue.configuration.cloud_manager}}
    end

    def self.cloud_data_file_name_base
      @file_name_base ||= "#{Pvcglue.configuration.cloud_name}.pvcglue.toml"
    end

    def self.manager_file_name
      File.join(manager_dir, cloud_data_file_name_base)
    end

    def self.user_name
      'pvcglue'
    end

    def self.home_dir
      File.join('/home', user_name)
    end

    def self.authorized_keys_file_name
      File.join(ssh_dir, 'authorized_keys')
    end

    def self.ssh_dir
      File.join(home_dir, '.ssh')
    end

    def self.manager_dir
      File.join(home_dir, '.pvc_manager')
    end

  end

end
