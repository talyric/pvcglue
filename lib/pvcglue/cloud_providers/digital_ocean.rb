module Pvcglue
  class CloudProviders
    REQUIRED_OPTIONS = %w(name region capacity image)

    class DigitalOcean < Pvcglue::CloudProviders

      def initialize(provider_options)
        @options = provider_options
      end

      def create(options)
        validate_options!(options)

        opts = options.to_h
        opts[:size] = opts.delete('capacity')

        droplet_options = DropletKit::Droplet.new(opts)
        droplet = client.droplets.create(droplet_options)
        Pvcglue.logger.debug("Created Digital Ocean droplet, ID:  #{droplet.id}")
        droplet
      end

      def ready?(minion)
        droplet = find_by_name(minion.machine_name)

        droplet.raw_data[:status] == 'active'
      end

      def find_by_name(minion_name)
        result = droplets.detect { |droplet| droplet.name == minion_name }
        normalize_machine_data(result) if result
      end

      def reload_machine_data(minion)
        find_by_name(minion.machine_name)
      end

      def normalize_machine_data(droplet)
        machine = ::SafeMash.new
        machine.raw_data = droplet
        machine.id = droplet.id.to_s
        machine.public_ip = get_public_ip(droplet)
        machine.private_ip = get_private_ip(droplet)
        machine.cloud_provider = 'digital-ocean'
        machine
      end

      def get_private_ip(droplet)
        get_ip_addresses(droplet).private
      end

      def get_public_ip(droplet)
        get_ip_addresses(droplet).public
      end

      def droplets
        client.droplets.all
        # @droplets ||= client.droplets.all
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
