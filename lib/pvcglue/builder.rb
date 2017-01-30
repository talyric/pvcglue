module Pvcglue
  class Builder < SafeMash
    include Hashie::Extensions::Mash::SafeAssignment

    def build!
      puts
      puts
      puts '*'*175
      puts "Building #{machine_name}"
      puts '-'*175

      # bootstrap



      puts '='*175
    end

    def provision!
      create! unless provisioned?
    end

    def provisioned?
      !!public_ip
    end

    def create!
      raise(Thor::Error, "#{cloud_provider.name} unknown") unless cloud_provider.name == 'digital-ocean'
      Pvcglue.logger.warn("Provisioning a VM for #{machine_name} on #{cloud_provider.name}...")

      # TODO:  Tags.  production, staging, load-balancer, web, worker, database, postgress, cache, memcache...
      name = machine_name
      size = capacity || cloud_provider.default_capacity
      image = cloud_provider.image
      region = cloud_provider.region
      # ap cloud_provider.initial_users
      # ap cloud_provider
      ssh_keys = cloud_provider.initial_users.map {|description, ssh_key| ssh_key}
      backups = cloud_provider.backups.nil? ? true : cloud_provider.backups # default to true -- safety first!
      tags = cloud_provider.tags

      # client.droplets.all.each do |droplet|
      #   ap droplet
      # end
      droplet = DropletKit::Droplet.new(
          name: name,
          region: region,
          image: image,
          size: size,
          ssh_keys: ssh_keys,
          backups: backups,
          ipv6: false,
          private_networking: true,
          user_data: '',
          monitoring: true,
          tags: tags
      )
      droplet = Pvcglue::DigitalOcean.client.droplets.create(droplet)
      self.droplet = droplet
      Pvcglue.logger.debug("Droplet ID:  #{droplet.id}")
      # ap created
      # raise(Thor::Error, 'STOP!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!')
      true
    end
  end
end
