module Pvcglue
  class Vagrant
    MACHINES = %w(manager lb web web_2 db memcached)

    def self.up
      if system("vagrant up")
        cache_info_for_machines
      else
        remove_cache_info_for_machines
        puts "Nope!"
      end

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


    def self.cache_info_for_machines
      machines = {}
      MACHINES.each do |machine|
        machines[machine] = {}
        data = `vagrant ssh #{machine} -c "ip a"`
        data.scan(/inet (.*)\/.*global (eth[01])/) do |ip, eth|
          type = eth == 'eth0' ? :private : :public
          machines[machine][type] = ip
        end
      end
      File.write(cache_file_name, machines.to_json)
      machines
    end

    def self.cache_file_name
      File.join(Pvcglue.configuration.application_dir, 'tmp', 'pvcglue-machines.json')
    end
  end
end
