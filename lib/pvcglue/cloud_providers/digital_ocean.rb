module Pvcglue
  class CloudProviders
    class DigitalOcean < Pvcglue::CloudProviders

      def initialize(provider_options)
        @options = provider_options
      end

      def create(options)
        validate_options!(options, %w(name region capacity image))
        #doctl compute droplet create test --size 512mb --image ubuntu-16-04-x64 --region sfo2 --ssh-keys d1:fe:e8:53:d4:fb:eb:f1:db:fc:ef:18:f1:cf:1e:5d --enable-backups --enable-private-networking
        cmd = "doctl compute droplet create #{options.name} "
        cmd += "--region #{options.region} "
        cmd += "--size #{options.capacity} "
        cmd += "--image '#{options.image}' "
        cmd += '--enable-private-networking '
        cmd += '--enable-monitoring '
        cmd += '--enable-backups ' if options.backups
        # cmd += "--tags '#{options.group}' " if options.group
        cmd += "--ssh-keys #{options.ssh_keys.join(',')} "
        cmd += '--output json'

        result = Pvcglue.system_get_stdout(cmd, true)
        array_data = JSON.parse(result)
        array_data.each { |h| h['size_data'] = h.delete('size') }
        data = []
        array_data.each do |machine|
          data << ::SafeMash.new(machine)
        end
        droplet = data.first
        Pvcglue.verbose? { data.inspect }
        Pvcglue.logger.debug("Created Digital Ocean droplet, ID:  #{droplet.id}")
        droplet
      end

      # def create(options)
      #   validate_options!(options, %w(name region capacity image))
      #   byebug
      #   opts = options.to_h
      #   opts[:size] = opts.delete('capacity')
      #
      #   droplet_options = DropletKit::Droplet.new(opts)
      #   droplet = client.droplets.create(droplet_options)
      #   Pvcglue.logger.debug("Created Digital Ocean droplet, ID:  #{droplet.id}")
      #   droplet
      # end
      #
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

      def run(cmd)
        result = Pvcglue.system_get_stdout(cmd, true)
        array_data = JSON.parse(result)
        array_data.each { |h| h['size_data'] = h.delete('size') }
        data = []
        array_data.each do |machine|
          data << ::SafeMash.new(machine)
        end
        Pvcglue.verbose? { data.inspect }
        [data, request_error(data)]
      end

      def request_error(data)
        # TODO:  Better error handling
        return nil # for now
        # return nil unless data.errors
        # raise data.errors.values.join('.  ')
      end

      def droplets
        # client.droplets.all
        # @droplets ||= client.droplets.all
        # return nil
        cmd = 'doctl compute droplet list --output json'

        result = Pvcglue.system_get_stdout(cmd, true)
        array_data = JSON.parse(result)
        array_data.each { |h| h['size_data'] = h.delete('size') }
        data = []
        array_data.each do |machine|
          data << ::SafeMash.new(machine)
        end
        Pvcglue.verbose? { data.inspect }
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
