module Pvcglue
  class Local
    # MACHINES = %w(manager lb web web_2 db memcached)
    MACHINES = %w(manager lb web db)

    def self.vagrant(command)
      raise(Thor::Error, "This command can only be used for the 'local' and 'test' stages.") unless Pvcglue.cloud.stage_name.in? %w(local test)
      raise(Thor::Error, "Vagrant (www.vagrantup.com) does not appear to be installed.  :(") unless vagrant_available?
      Bundler.with_clean_env { system("vagrant #{command}") }
    end

    def self.vagrant_available?
      # puts Bundler.with_clean_env { `vagrant --version` }
      Bundler.with_clean_env { `vagrant --version` } =~ /Vagrant \d+\.\d+\.\d+/
    end

    def self.system_live_out(cmd)
      raise($?) unless system(cmd, out: $stdout, err: :out)
    end

    def self.up
      start
      system_live_out('pvc manager bootstrap')
      system_live_out('pvc manager push')
      system_live_out('pvc local pvcify')
      system_live_out('pvc manager push')
      system_live_out('pvc local bootstrap')
      system_live_out('pvc local build')
      system_live_out('pvc local deploy')
    end

    def self.start
      FileUtils.rm_rf(local_cache_dir)

      if vagrant("up #{machines_in_stage}")
        update_local_config(get_info_for_machines)
        # get_ssh_config
      else
        remove_cache_info_for_machines
        raise(Thor::Error, "Error starting virtual machines.  :(")
      end
    end

    def self.machines_in_stage
      "/#{Pvcglue.cloud.stage_name}-\\|manager/" # must escape '|' for shell
    end

    def self.update_local_config_from_cache
      data = File.read(machine_cache_file_name)
      machines = JSON.parse(data)
      update_local_config(machines)
    end

    def self.get_machine_ip_address
      result = `ip route get 8.8.8.8 2>&1 | awk '{print $NF; exit}'`.strip # Ubuntu
      result = `ipconfig getifaddr en0 2>&1` unless result =~ /\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/ # OSX
      raise "IP Address not found" unless result =~ /\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/
      puts "*"*80
      puts "Machine IP address #{result}"
      result
    end

    def self.update_local_config(machines)
      machines = machines.with_indifferent_access
      Pvcglue::Manager.set_local_mode
      manager_file_name = Pvcglue::Configuration.project_file_name
      data = File.exists?(manager_file_name) ? TOML.load_file(manager_file_name) : {}
      # puts data.inspect
      # puts machines.inspect
      # puts machines[:manager][:public_ip].inspect
      manager_ip = machines[:manager][:public_ip].to_s # to_s in case it's nil, as 'nil' is invalid TOML
      raise(Thor::Error, "Manager IP is not valid. :(") unless manager_ip =~ /\b(?:\d{1,3}\.){3}\d{1,3}\b/
      data["local_cloud_manager"] = manager_ip
      # data["#{Pvcglue.cloud.stage_name}_cloud_manager"] = manager_ip
      File.write(manager_file_name, TOML.dump(data.stringify_keys))

      app_name = Pvcglue.configuration.application_name
      data = {}
      data = TOML.load_file(::Pvcglue.cloud.local_file_name) if File.exists?(::Pvcglue.cloud.local_file_name)
      data = TOML.load_file(Pvcglue.configuration.cloud_cache_file_name) if data.empty? && File.exists?(Pvcglue.configuration.cloud_cache_file_name)
      # TODO:  get repo_url from git, if possible
      puts "*"*80
      puts data.inspect
      if data.empty?
        data = {app_name =>
                    {"excluded_db_tables" => ["versions"],
                     "name" => app_name,
                     "repo_url" => "git@github.com:talyric/pvcglue-dev-box.git", # TODO: get with git
                     "ssh_allowed_from_all_port" => "22222",
                     "swapfile_size" => 128,
                     "time_zone" => "America/Los_Angeles",
                     "authorized_keys" => {"example" => File.read(File.expand_path('~/.ssh/id_rsa.pub'))}, # TODO: error checking
                     "dev_ip_addresses" => {"local" => "127.0.0.1", "user" => get_machine_ip_address},
                     "gems" => {"delayed_job" => false, "whenever" => false},
                     "stages" =>
                         {"local" =>
                              {"db_rebuild" => true,
                               "domains" => ["#{app_name}.local"],
                               "ssl" => "none",
                               "roles" => {
                                   # "caching" =>
                                   #      {"memcached" => {"private_ip" => "0.0.0.0", "public_ip" => "0.0.0.0"}},
                                   "redis" =>
                                        {"redis" => {"private_ip" => "0.0.0.0", "public_ip" => "0.0.0.0"}},
                                    "db" => {"db" => {"private_ip" => "0.0.0.0", "public_ip" => "0.0.0.0"}},
                                    "lb" =>
                                        {"lb" =>
                                             {"allow_public_access" => true,
                                              "private_ip" => "0.0.0.0",
                                              "public_ip" => "0.0.0.0"}},
                                    "web" => {"web_1" => {"private_ip" => "0.0.0.0", "public_ip" => "0.0.0.0"}}}},
                          "test" =>
                              {"db_rebuild" => false,
                               "domains" => ["#{app_name}.test"],
                               "ssl" => "none",
                               "roles" =>
                                   {"caching" =>
                                        {"memcached" => {"private_ip" => "0.0.0.0", "public_ip" => "0.0.0.0"}},
                                    "db" => {"db" => {"private_ip" => "0.0.0.0", "public_ip" => "0.0.0.0"}},
                                    "lb" =>
                                        {"lb" =>
                                             {"allow_public_access" => true,
                                              "private_ip" => "0.0.0.0",
                                              "public_ip" => "0.0.0.0"}},
                                    "web" =>
                                        {"web_1" => {"private_ip" => "0.0.0.0", "public_ip" => "0.0.0.0"}}}}}}}
      end
      data = data.with_indifferent_access

      # pp data
      # pp machines
      # puts "*"*80
      # puts machines[:memcached][:public_ip].inspect
      # puts "*"*80
      # puts data[app_name].inspect
      # puts "*"*80
      # puts data[app_name][:stages].inspect
      # puts "*"*80
      # puts data[app_name][:stages][:local].inspect
      # puts "*"*80
      # puts data[app_name][:stages][:local][:roles].inspect
      # puts "*"*80
      # puts data[app_name][:stages][:local][:roles][:caching].inspect
      # puts "*"*80
      # puts data[app_name][:stages][:local][:roles][:caching][:memcached].inspect
      # puts "*"*80
      # puts data[app_name][:stages][:local][:roles][:caching][:memcached][:public_ip].inspect
      # puts "*"*80
      stage_name = Pvcglue.cloud.stage_name
      # stage_name = :local
      # data[app_name][:stages][stage_name][:roles][:caching][:memcached][:public_ip] = machines[:memcached][:public_ip]
      # data[app_name][:stages][stage_name][:roles][:caching][:memcached][:private_ip] = machines[:memcached][:private_ip]
      data[app_name][:stages][stage_name][:roles][:db][:db][:public_ip] = machines[:db][:public_ip].to_s # to_s in case it's nil, as 'nil' is invalid TOML
      data[app_name][:stages][stage_name][:roles][:db][:db][:private_ip] = machines[:db][:private_ip].to_s # to_s in case it's nil, as 'nil' is invalid TOML
      data[app_name][:stages][stage_name][:roles][:redis][:redis][:public_ip] = machines[:db][:public_ip].to_s # to_s in case it's nil, as 'nil' is invalid TOML
      data[app_name][:stages][stage_name][:roles][:redis][:redis][:private_ip] = machines[:db][:private_ip].to_s # to_s in case it's nil, as 'nil' is invalid TOML
      data[app_name][:stages][stage_name][:roles][:lb][:lb][:public_ip] = machines[:lb][:public_ip].to_s # to_s in case it's nil, as 'nil' is invalid TOML
      data[app_name][:stages][stage_name][:roles][:lb][:lb][:private_ip] = machines[:lb][:private_ip].to_s # to_s in case it's nil, as 'nil' is invalid TOML
      data[app_name][:stages][stage_name][:roles][:web][:web_1][:public_ip] = machines[:web][:public_ip].to_s # to_s in case it's nil, as 'nil' is invalid TOML
      data[app_name][:stages][stage_name][:roles][:web][:web_1][:private_ip] = machines[:web][:private_ip].to_s # to_s in case it's nil, as 'nil' is invalid TOML

      # puts "*"*80
      # puts machines.inspect
      data[app_name][:dev_ip_addresses] = {"local" => "127.0.0.1", "user" => get_machine_ip_address.to_s} # to_s in case it's nil, as 'nil' is invalid TOML
      # data[app_name][:stages][stage_name][:domains] = [[machines[:lb][:public_ip]].to_s] # to_s in case it's nil, as 'nil' is invalid TOML
      data[app_name][:stages][stage_name][:domains] = [machines[:lb][:public_ip] || ''] # to_s in case it's nil, as 'nil' is invalid TOML

      # data[app_name][:stages][:local][:roles][:web][:web_2][:public_ip] = machines[:web_2][:public_ip]
      # data[app_name][:stages][:local][:roles][:web][:web_2][:private_ip] = machines[:web_2][:private_ip]

      Pvcglue.cloud.data = data
      File.write(::Pvcglue.cloud.local_file_name, TOML::PvcDumper.new(Pvcglue.cloud.data).toml_str)
      File.write(Pvcglue.configuration.cloud_cache_file_name, TOML::PvcDumper.new(Pvcglue.cloud.data).toml_str)
      # puts TOML::PvcDumper.new(Pvcglue.cloud.data).toml_str
    end

    def self.stop
      vagrant("halt #{machines_in_stage}")
    end

    def self.restart
      vagrant("reload #{machines_in_stage}")
    end

    def self.rebuild
      vagrant("destroy #{machines_in_stage} --force")
      start
    end

    def self.destroy
      vagrant("destroy #{machines_in_stage} --force")
    end

    def self.suspend
      vagrant("suspend #{machines_in_stage}")
    end

    def self.kill
      vagrant("halt #{machines_in_stage} --force")
    end

    def self.status
      vagrant("status")
    end

    def self.remove_cache_info_for_machines
      File.delete(machine_cache_file_name)
    end

=begin
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 08:00:27:e7:ab:02 brd ff:ff:ff:ff:ff:ff
    inet 10.0.2.15/24 brd 10.0.2.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fee7:ab02/64 scope link
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 08:00:27:8e:64:5a brd ff:ff:ff:ff:ff:ff
    inet 10.10.10.208/24 brd 10.10.10.255 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe8e:645a/64 scope link
       valid_lft forever preferred_lft forever
4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 08:00:27:9a:14:92 brd ff:ff:ff:ff:ff:ff
    inet 172.28.128.3/24 brd 172.28.128.255 scope global eth2
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe9a:1492/64 scope link
       valid_lft forever preferred_lft forever
=end


    def self.get_info_for_machines
      machines = {}
      vagrant_ips = []
      MACHINES.each do |machine|
        machines[machine] = {}
        machine_name = machine == 'manager' ? machine : "#{Pvcglue.cloud.stage_name}-#{machine}"
        puts "Getting networking info from #{machine_name}..."
        data = `vagrant ssh #{machine_name} -c "ip a"`
        puts data
        data.scan(/inet (.*)\/.*global (eth[12])/) do |ip, eth|
          type = eth == 'eth2' ? :private_ip : :public_ip
          machines[machine][type] = ip
        end
        data.scan(/inet (.*)\/.*global (eth0)/) do |ip, eth|
          vagrant_ips << ip
        end
        raise "Public IP not found" unless machines[machine][:public_ip]
        raise "Private IP not found" unless machines[machine][:private_ip]
        puts "Adding your public key to the root user for #{machine_name}..."
        # cat ~/.ssh/id_rsa.pub | vagrant ssh manager -c 'sudo tee /root/.ssh/authorized_keys'
        raise $? unless system %Q(cat ~/.ssh/id_rsa.pub | vagrant ssh #{machine_name} -c 'sudo tee /root/.ssh/authorized_keys')
      end
      FileUtils.mkdir_p(File.dirname(machine_cache_file_name)) # the 'tmp' directory may not always exist
      File.write(machine_cache_file_name, machines.to_json)
      FileUtils.mkdir_p(File.dirname(vagrant_config_cache_file_name)) # the 'tmp' directory may not always exist
      File.write(vagrant_config_cache_file_name, vagrant_ips.to_json)
      # puts machines.inspect
      machines
    end

    # def self.get_ssh_config
    #   data = `vagrant ssh-config`
    #   puts data
    #   out = {}
    #   data.scan(/Host (.*?)$.*?Port (.*?)$/m) do |host_name, port|
    #     out[host_name] = port
    #   end
    #   FileUtils.mkdir_p(File.dirname(ssh_config_cache_file_name)) # the 'tmp' directory may not always exist
    #   File.write(ssh_config_cache_file_name, out.to_json)
    #   puts out.inspect
    #   out
    # end

    def self.vagrant_config
      ips = JSON.parse(File.read(vagrant_config_cache_file_name))
      # puts ips.inspect
      ip = ips.first
      parts = ip.split('.')
      parts[0..2].join('.') + '.0/24'
    end

    def self.local_cache_dir
      Pvcglue.configuration.pvcglue_tmp_dir
    end

    def self.machine_cache_file_name
      # TODO:  Remove caching, maybe?
      File.join(local_cache_dir, 'pvcglue-machines.json')
    end

    def self.vagrant_config_cache_file_name
      # TODO:  Remove caching, maybe?
      File.join(local_cache_dir, 'pvcglue-ssh-config.json')
    end
  end


  # def self.local
  #   @local ||= Local.new
  # end

  # def self.local=(config)
  #   @local = config
  # end

end
