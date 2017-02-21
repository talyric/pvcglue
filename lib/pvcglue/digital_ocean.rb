module Pvcglue
  class DigitalOcean

    def self.client
      @@client ||= get_client
    end

    def self.get_client
      access_token = YAML::load(File.open(File.join(ENV['HOME'], '.config/doctl/config.yaml')))['access-token']
      ::DropletKit::Client.new(access_token: access_token)
    end

    def self.get_ip_addresses(droplet)
      ips = ::SafeMash.new
      droplet.networks.v4.each do |network|
        ips[network.type] = network.ip_address
      end
      ips
    end
  end
end
