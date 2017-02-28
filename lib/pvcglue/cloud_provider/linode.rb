module Pvcglue
  class CloudHost
    class Linode

      def create(options)
        cmd = "linode create #{options.name} "
        cmd += "--location #{options.region} "
        cmd += "--plan #{options.size} "
        cmd += '--payment-term 1 '
        cmd += "--distribution '#{options.image}' "
        cmd += "--group #{options.group} " if options.group
        cmd += "--password #{SecureRandom.hex} "
        cmd += '--json'

        byebug

        result = Pvcglue.system_get_stdout(cmd)
        data = ::SafeMash.new(JSON.parse(result))
        Pvcglue.logger.debug("Created Linode, ID:  #{droplet.id}")
        data
      end

      def find(options)

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
