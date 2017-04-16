module Pvcglue
  class CloudProviders
    class Linode < Pvcglue::CloudProviders

      def initialize(provider_options)
        @options = provider_options
      end

      def create(options)
        validate_options!(options, %w(name region capacity image))

        cmd = "linode create #{options.name} "
        cmd += "--location #{options.region} "
        cmd += "--plan #{options.capacity} "
        cmd += '--payment-term 1 '
        cmd += "--distribution '#{options.image}' "
        cmd += "--group '#{options.group}' " if options.group
        cmd += "--password #{generate_password} "
        cmd += "--pubkey-file '#{File.expand_path('~/.ssh/id_rsa.pub')}' "
        cmd += '--json'

        data, error = run(cmd)
        raise(error) if error.present?

        cmd = "linode ip-add --label #{options.name} --private "
        cmd += '--json'
        data, error = run(cmd)
        raise(error) if error.present?

        #<SafeMash staging-lb=#<SafeMash job="start" jobid=45919584 message="Completed. Booting staging-lb..." request_action="create" request_error="">>
        machine = find_by_name(options.name)
        Pvcglue.logger.debug("Created Linode, ID:  #{machine.id}")
        machine
      end

      def generate_password
        password = "#{SecureRandom.hex}a1" # ensure required 'character classes'
        Pvcglue.verbose? { password }
        password
      end

      def reload_machine_data(minion)
        find_by_name(minion.machine_name)
      end

      def ready?(minion)
        machine = find_by_name(minion.machine_name)
        machine.raw_data.values.first.status == 'running'
      end

      def find_by_name(name)
        # return nil
        cmd = "linode show --label #{name} "
        cmd += '--json'

        data, error = run(cmd)
        if error =~ /Couldn't find/
          return nil
        elsif error.present?
          raise(error)
        end
        normalize_machine_data(data)
      end

=begin
> linode show staging-lb --json
{
   "staging-lb" : {
      "backupsenabled" : false,
      "totalram" : "1.00GB",
      "group" : "",
      "request_error" : "",
      "ips" : [
         "192.168.132.194",
         "104.237.159.149"
      ],
      "location" : "fremont",
      "totalhd" : "20.00GB",
      "status" : "running",
      "label" : "staging-lb",
      "request_action" : "show",
      "linodeid" : 2817249
   }
}
=end
      def normalize_machine_data(data)
        machine = ::SafeMash.new
        machine.raw_data = data
        machine.id = data.values.first.linodeid
        machine.public_ip = get_public_ip(data.values.first.ips)
        machine.private_ip = get_private_ip(data.values.first.ips)
        machine.cloud_provider = 'linode'
        machine
      end

      def get_private_ip(ips)
        ips.each { |ip| return ip if is_private?(ip) }
        nil
      end

      def get_public_ip(ips)
        ips.each { |ip| return ip unless is_private?(ip) }
        nil
      end

      def is_private?(ip)
        ip =~ /^(?:10|127|172\.(?:1[6-9]|2[0-9]|3[01])|192\.168)\..*/m
      end


      def run(cmd)
        result = Pvcglue.system_get_stdout(cmd)
        data = ::SafeMash.new(JSON.parse(result))
        Pvcglue.verbose? { data.inspect }
        [data, request_error(data)]
      end

      def request_error(data)
        data.values.first.request_error
      end

      # def get_ip_addresses(droplet)
      #   ips = ::SafeMash.new
      #   droplet.networks.v4.each do |network|
      #     ips[network.type] = network.ip_address
      #   end
      #   ips
      # end
    end
  end
end
