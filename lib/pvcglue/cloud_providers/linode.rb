module Pvcglue
  class CloudProviders
    REQUIRED_OPTIONS = %w(name region capacity image)

    class Linode < Pvcglue::CloudProviders

      def create(options)
        validate_options!(options)

        cmd = "linode create #{options.name} "
        cmd += "--location #{options.region} "
        cmd += "--plan #{options.capacity} "
        cmd += '--payment-term 1 '
        cmd += "--distribution '#{options.image}' "
        cmd += "--group #{options.group} " if options.group
        cmd += "--password #{SecureRandom.hex}a1 " # ensure required 'character classes'
        cmd += "--pubkey-file '#{File.expand_path('~/.ssh/id_rsa.pub')}' "
        cmd += '--json'

        result = Pvcglue.system_get_stdout(cmd)
        data = ::SafeMash.new(JSON.parse(result))
        byebug
        #<SafeMash staging-lb=#<SafeMash job="start" jobid=45919584 message="Completed. Booting staging-lb..." request_action="create" request_error="">>
        Pvcglue.logger.debug("Created Linode, ID:  #{droplet.id}")
        data
      end

      def find(options)

      end

      def find_by_name(name)
        # return nil
        cmd = "linode show --label #{name} "
        cmd += '--json'

        result = Pvcglue.system_get_stdout(cmd)
        data = ::SafeMash.new(JSON.parse(result))
        if data[name].request_error.present?
          data = nil
        end
        data
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
