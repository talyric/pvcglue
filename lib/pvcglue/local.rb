module Pvcglue
  class Local
    MACHINES = %w(manager lb web web_2 db memcached)

    def self.vagrant(command)
      raise(Thor::Error, "Vagrant (www.vagrantup.com) does not appear to be installed.  :(") unless vagrant_available?
      Bundler.with_clean_env { system("vagrant #{command}") }
    end

    def self.vagrant_available?
      # puts Bundler.with_clean_env { `vagrant --version` }
      Bundler.with_clean_env { `vagrant --version` } =~ /Vagrant \d+\.\d+\.\d+/
    end

    def self.start
      if vagrant("up")
        update_local_config(get_info_for_machines)
      else
        remove_cache_info_for_machines
        raise(Thor::Error, "Error starting virtual machines.  :(")
      end
    end

    def self.update_local_config_from_cache
      data = File.read(cache_file_name)
      machines = JSON.parse(data)
      update_local_config(machines)
    end

    def self.update_local_config(machines)
      machines = machines.with_indifferent_access
      Pvcglue::Manager.set_local_mode
      manager_file_name = Pvcglue::Configuration.project_file_name
      data = File.exists?(manager_file_name) ? TOML.load_file(manager_file_name) : {}
      # puts data.inspect
      # puts machines.inspect
      # puts machines[:manager][:public_ip].inspect
      data[:local_cloud_manager] = machines[:manager][:public_ip]
      File.write(manager_file_name, TOML.dump(data.stringify_keys))

      app_name = Pvcglue.configuration.application_name
      data = {}
      data = TOML.load_file(::Pvcglue.cloud.local_file_name) if File.exists?(::Pvcglue.cloud.local_file_name)
      data = TOML.load_file(Pvcglue.configuration.cloud_cache_file_name) if data.empty? && File.exists?(Pvcglue.configuration.cloud_cache_file_name)
      # TODO:  get repo_url from git, if possible
      if data.empty?
        data = {app_name =>
                    {"excluded_db_tables" => ["versions"],
                     "name" => app_name,
                     "repo_url" => "git@github.com:talyric/pvcglue-dev-box.git",
                     "ssh_allowed_from_all_port" => "22222",
                     "swapfile_size" => 128,
                     "time_zone" => "America/Los_Angeles",
                     "authorized_keys" => {"example" => "ssh-rsa AAA...ZZZ== example@dev.local"},
                     "dev_ip_addresses" => {"example" => "127.0.0.1"},
                     "gems" => {"delayed_job" => false, "whenever" => false},
                     "stages" =>
                         {"local" =>
                              {"db_rebuild" => true,
                               "domains" => ["#{app_name}.local"],
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

      data[app_name][:stages][:local][:roles][:caching][:memcached][:public_ip] = machines[:memcached][:public_ip]
      data[app_name][:stages][:local][:roles][:caching][:memcached][:private_ip] = machines[:memcached][:private_ip]
      data[app_name][:stages][:local][:roles][:db][:db][:public_ip] = machines[:db][:public_ip]
      data[app_name][:stages][:local][:roles][:db][:db][:private_ip] = machines[:db][:private_ip]
      data[app_name][:stages][:local][:roles][:lb][:lb][:public_ip] = machines[:lb][:public_ip]
      data[app_name][:stages][:local][:roles][:lb][:lb][:private_ip] = machines[:lb][:private_ip]
      data[app_name][:stages][:local][:roles][:web][:web_1][:public_ip] = machines[:web][:public_ip]
      data[app_name][:stages][:local][:roles][:web][:web_1][:private_ip] = machines[:web][:private_ip]
      # data[app_name][:stages][:local][:roles][:web][:web_2][:public_ip] = machines[:web_2][:public_ip]
      # data[app_name][:stages][:local][:roles][:web][:web_2][:private_ip] = machines[:web_2][:private_ip]

      Pvcglue.cloud.data = data
      File.write(::Pvcglue.cloud.local_file_name, TOML.dump(Pvcglue.cloud.data))
      File.write(Pvcglue.configuration.cloud_cache_file_name, TOML.dump(Pvcglue.cloud.data))
    end

    def self.stop
      vagrant("halt")
    end

    def self.restart
      vagrant("reload")
    end

    def self.rebuild
      vagrant("destroy --force")
      start
    end

    def self.destroy
      vagrant("destroy --force")
    end

    def self.suspend
      vagrant("suspend")
    end

    def self.kill
      vagrant("halt --force")
    end

    def self.status
      vagrant("status")
    end

    def self.remove_cache_info_for_machines
      File.delete(cache_file_name)
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
      MACHINES.each do |machine|
        machines[machine] = {}
        puts "Getting networking info from #{machine}..."
        data = `vagrant ssh #{machine} -c "ip a"`
        puts data
        data.scan(/inet (.*)\/.*global (eth[12])/) do |ip, eth|
          type = eth == 'eth2' ? :private_ip : :public_ip
          machines[machine][type] = ip
        end
        puts "Adding you public key to the root user for #{machine}..."
        # cat ~/.ssh/id_rsa.pub | vagrant ssh manager -c 'sudo tee /root/.ssh/authorized_keys'
        raise $? unless system %Q(cat ~/.ssh/id_rsa.pub | vagrant ssh #{machine} -c 'sudo tee /root/.ssh/authorized_keys')
      end
      File.write(cache_file_name, machines.to_json)
      machines
    end

    def self.cache_file_name
      File.join(Pvcglue::Configuration.application_dir, 'tmp', 'pvcglue-machines.json')
    end
  end


  # def self.local
  #   @local ||= Local.new
  # end

  # def self.local=(config)
  #   @local = config
  # end

end
