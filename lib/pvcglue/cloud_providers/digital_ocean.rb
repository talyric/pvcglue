module Pvcglue
  class CloudProviders
    class DigitalOcean < Pvcglue::CloudProviders

    def create(options)
        droplet_options = DropletKit::Droplet.new(options)
        droplet = client.droplets.create(droplet_options)
        Pvcglue.logger.debug("Created Digital Ocean droplet, ID:  #{droplet.id}")
        droplet
      end

      def find(options)

      end

      def find_by_name(name)
        raise 'not ready yet!'
      end

      def client
        @client ||= get_client
      end

      def get_client
        access_token = YAML::load(File.open(File.join(ENV['HOME'], '.config/doctl/config.yaml')))['access-token']
        ::DropletKit::Client.new(access_token: access_token)
      end

      def get_ip_addresses(droplet)
        ips = ::SafeMash.new
        droplet.networks.v4.each do |network|
          ips[network.type] = network.ip_address
        end
        ips
      end
    end
  end
end
