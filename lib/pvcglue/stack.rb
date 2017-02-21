module Pvcglue
  class Stack
    def self.build(minions, roles_filter)
      Pvcglue::Stack.new(roles_filter).run(minions)
    end

    def initialize(roles_filter)
      @roles_filter = roles_filter
    end

    def apply_role?(role)
      @roles_filter == 'all' || role == @roles_filter
    end

    def run(minions)
      # puts "Configuring nodes for #{@roles_filter}."

      # ap Pvcglue.configuration
      # ap Pvcglue.cloud.data
      # ap Pvcglue.cloud.app_name
      # ap Pvcglue.cloud.project
      # ap Pvcglue.cloud.project.name
      # ap Pvcglue.cloud.project.stages.map { |stage| stage.to_dot.stage }
      # ap Pvcglue.cloud.project.stages.map { |stage| stage.name }
      # ap Pvcglue.cloud.stage
      # ap Pvcglue.cloud.minions
      # ap Pvcglue.cloud.minions.map { |key, value| value.roles }
      # minions.each do |minion_name, minion|
      #   ap minion_name
      #   ap minion.first
      # end
      # ap minions['staging-pg'].private_ip
      # minions['staging-pg'].private_ip = '127.0.0.1'
      # ap minions['staging-pg'].private_ip
      new_minions = []
      minions.each do |minion_name, minion|
        Pvcglue.logger_current_minion = minion
        # droplet = Pvcglue::DigitalOcean.client.droplets.find(id: 38371925)
        # minion.droplet = droplet
        # new_minions << minion if true || minion.provision!
        unless minion.provisioned?
          if droplets.detect { |droplet| droplet.name == minion_name }
            raise(Thor::Error, "Machine with the name of '#{minion_name}' already exists!")
          end
          minion.provision!
          new_minions << minion
        end
      end
      Pvcglue.logger_current_minion = nil

      if new_minions.size > 0
        # ap new_minions
        Pvcglue.logger.info("Checking status of new minions (#{new_minions.size})...")
        time = Benchmark.realtime do
          begin
            lazy_minions = get_lazy_minions(minions)
            unless lazy_minions.size == 0
              # puts '*'*175
              # ap waiting_for
              Pvcglue.logger.info("Waiting for #{lazy_minions.map { |key, value| key }.join(', ')}...")
              sleep(1.5)
            end
          end until lazy_minions.size == 0
          updated_minions = write_config(new_minions)
          updated_minions.each do |updated_minion|
            minions[updated_minion.machine_name].private_ip = updated_minion.private_ip
            minions[updated_minion.machine_name].public_ip = updated_minion.public_ip
            minions[updated_minion.machine_name].cloud_id = updated_minion.cloud_id
            minions[updated_minion.machine_name].connection = Pvcglue::Connection.new(minions[updated_minion.machine_name])
          end
        end
        Pvcglue.logger.info("Minions (finally) ready after #{time.round(2)} seconds!")
        # Pvcglue.cloud.reload_minions!
      end

      minions.each do |minion_name, minion|
        next unless minion.has_role?(@roles_filter)
        Pvcglue.logger_current_minion = minion
        minion.build!
      end
      Pvcglue.logger_current_minion = nil

      # raise(Thor::Error, 'STOP!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!')
      #
      # %w(lb db web caching redis).each do |role|
      #   if apply_role?(role)
      #     Pvcglue::Packages.apply(role.to_sym, :build, Pvcglue.cloud.minions_filtered(role))
      #   end
      # end

      Pvcglue::Pvcify.run unless minions.values.first.minion_manager?

    end

    def write_config(minions)
      # TODO:  Just read and write the configuration from manager without writing to `minion.cloud.local_file_name`
      Pvcglue::Manager.pull_configuration
      data = File.read(Pvcglue.cloud.local_file_name)
      updated_minions = minions.map do |minion|
        # puts '-'*175
        # ap minion.droplet
        # Refresh droplet (didn't find a reload method)
        droplet_id = minion.droplet.id.to_s
        # ap droplet_id
        minion.droplet = Pvcglue::DigitalOcean.client.droplets.find(id: droplet_id)
        # puts '='*175
        # ap minion.droplet
        ip_addresses = Pvcglue::DigitalOcean.get_ip_addresses(minion.droplet)
        data = update_minion_data(minion, ip_addresses, droplet_id, data)
        minion.public_ip = ip_addresses.public
        minion.private_ip = ip_addresses.private
        minion.cloud_id = droplet_id
        minion
      end
      File.write(Pvcglue.cloud.local_file_name, data)
      Pvcglue::Manager.push_configuration
      updated_minions
    end

    def update_minion_data(minion, ip_addresses, cloud_id, data)
      unless minion.public_ip_address.nil? && minion.private_id_address.nil? && minion.cloud_id.nil?
        raise(Thor::Error, "#{minion.machine_name} has previously defined ip address(es) or cloud_id, can not change.")
      end
      if ip_addresses.public.nil? || ip_addresses.private.nil? || cloud_id.nil?
        raise(Thor::Error, "New IP addresses (#{ip_addresses}) or cloud_id (#{cloud_id}) are not valid.")
      end


      replacement = "\\1\\2\n\\1public_ip = '#{ip_addresses.public}'\n\\1private_ip = '#{ip_addresses.private}'\n\\1cloud_id = '#{cloud_id}'"
      new_data = data.sub(/( *)(name\s*=\s*['"]#{Regexp.quote(minion.machine_name)}['"])/, replacement)
      raise "Unable to update minion data for #{minion.machine_name}." if data == new_data

      # replacement = "$1$2\n$1public_ip = '#{ip_addresses.public}'\n$1private_ip = '#{ip_addresses.private}'"
      # new_data = data.sub(/( *)(name\s*=\s*['"]staging-lb['"])/) do |match|
      #   "#{$1}#{$2}\n#{$1}public_ip = '#{ip_addresses.public}'\n#{$1}private_ip = '#{ip_addresses.private}'"
      # end
      # puts new_data


      Pvcglue.logger.debug("Updated configuration for machine named #{minion.machine_name}.")
      new_data
    end

    def droplets
      @droplets ||= Pvcglue::DigitalOcean.client.droplets.all
    end

    def get_lazy_minions(minions)
      droplets = Pvcglue::DigitalOcean.client.droplets.all

      minions.select do |minion_name, minion|
        Pvcglue.logger_current_minion = minion
        # next unless minion.machine_name == 'staging-lb'
        # ap minion_name
        found = droplets.detect do |droplet|
          droplet[:name] == minion.machine_name
        end
        # ap found
        # ap found[:status]
        !found || found[:status] != 'active'
      end
      # ap minions
    end

  end
end
