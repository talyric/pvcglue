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
        next unless minion.has_role?(@roles_filter)
        Pvcglue.logger_current_minion = minion
        # droplet = Pvcglue::DigitalOcean.client.droplets.find(id: 38371925)
        # minion.droplet = droplet
        # new_minions << minion if true || minion.provision!
        unless minion.provisioned?
          existing_machine = minion.pvc_cloud_provider.find_by_name(minion_name)
          if existing_machine
            Pvcglue.logger.warn("Machine with the name of '#{minion_name}' already exists.")
            if Thor::Shell::Basic.new.yes?("Existing machine found.  Do you want to use #{existing_machine.id} for #{minion_name}")
              minion.machine = existing_machine
              new_minions << minion
            else
              Pvcglue.logger.error("Machine with the name of '#{minion_name}' already exists.")
              raise("Machine with the name of '#{minion_name}' already exists.")
            end
          else
            minion.provision!
            new_minions << minion
          end
        end
      end
      Pvcglue.logger_current_minion = nil

      if new_minions.size > 0
        # ap new_minions
        Pvcglue.logger.info("Checking status of new minions (#{new_minions.size})...")
        time = Benchmark.realtime do
          begin
            lazy_minions = get_lazy_minions(new_minions)
            unless lazy_minions.size == 0
              # puts '*'*175
              # ap waiting_for
              Pvcglue.logger.info("Waiting for #{lazy_minions.map { |minion| minion.machine_name }.join(', ')}...")
              sleep(1.5)
            end
          end until lazy_minions.size == 0
          updated_minions = write_config(new_minions)
          updated_minions.each do |updated_minion|
            minions[updated_minion.machine_name].private_ip = updated_minion.private_ip
            minions[updated_minion.machine_name].public_ip = updated_minion.public_ip
            minions[updated_minion.machine_name].cloud_id = updated_minion.cloud_id
            minions[updated_minion.machine_name].connection = Pvcglue::Connection.new(minions[updated_minion.machine_name])
            Pvcglue::Packages::SshKeyCheck.apply(minions[updated_minion.machine_name])
          end
        end
        Pvcglue.logger.info("Minions (finally) ready after #{time.round(2)} seconds!")
        # Pvcglue.cloud.reload_minions!
      end

      unless Pvcglue.command_line_options[:provision_only]
        minions.each do |minion_name, minion|
          next unless minion.has_role?(@roles_filter)
          Pvcglue.logger_current_minion = minion
          minion.build!
        end

        Pvcglue.logger_current_minion = nil

        Pvcglue::Pvcify.run unless minions.values.first.minion_manager?
      end
    end

    def write_config(minions)
      # TODO:  Just read and write the configuration from manager without writing to `minion.cloud.local_file_name`
      Pvcglue::Manager.pull_configuration
      data = File.read(Pvcglue.cloud.local_file_name)
      updated_minions = minions.map do |minion|
        # # puts '-'*175
        # # ap minion.droplet
        # # Refresh droplet (didn't find a reload method)
        # droplet_id = minion.droplet.id.to_s
        # # ap droplet_id
        # minion.droplet = Pvcglue::CloudProvider.client.droplets.find(id: droplet_id)
        # # puts '='*175
        # # ap minion.droplet
        # ip_addresses = Pvcglue::CloudProvider.get_ip_addresses(minion.droplet)
        # data = update_minion_data(minion, ip_addresses, droplet_id, data)
        # minion.public_ip = ip_addresses.public
        # minion.private_ip = ip_addresses.private
        # minion.cloud_id = droplet_id
        # minion

        minion.machine = minion.pvc_cloud_provider.reload_machine_data(minion)
        data = update_minion_data(minion, data)
        minion.public_ip = minion.machine.public_ip
        minion.private_ip = minion.machine.private_ip
        minion.cloud_id = minion.machine.id

        minion
      end
      File.write(Pvcglue.cloud.local_file_name, data)
      Pvcglue::Manager.push_configuration
      updated_minions
    end

    # def update_minion_data(minion, ip_addresses, cloud_id, data)
    def update_minion_data(minion, data)
      unless minion.public_ip.nil? && minion.private_ip.nil? && minion.cloud_id.nil?
        raise("#{minion.machine_name} has previously defined ip address(es) or id, can not change.  As a safety measure, you will need to manually remove any old data")
      end
      if minion.machine.public_ip.nil? || minion.machine.private_ip.nil? || minion.machine.id.nil?
        raise("New public IP address (#{minion.machine.public_ip}) or private IP address (#{minion.machine.private_ip}) or cloud_id (#{minion.machine.id}) are not valid.")
      end


      replacement = "\\1\\2\n\\1public_ip = '#{minion.machine.public_ip}'\n\\1private_ip = '#{minion.machine.private_ip}'\n\\1cloud_id = '#{minion.machine.id}'"
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

    def machines
      @machines ||= Pvcglue::CloudProvider.client.droplets.all
    end

    def get_lazy_minions(minions)
      minions.select do |minion|
        Pvcglue.logger_current_minion = minion
        !minion.pvc_cloud_provider.ready?(minion)
      end
    end

  end
end
