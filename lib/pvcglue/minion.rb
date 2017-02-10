module Pvcglue
  class Minion < SafeMash
    include Hashie::Extensions::Mash::SafeAssignment

    def build!
      # puts '*'*175
      Pvcglue.logger.info('BUILD') { "Building #{machine_name}" }

      minion = self # for readability
      Pvcglue::Packages::SshKeyCheck.apply(minion)
      Pvcglue::Packages::AptRepos.apply(minion)
      Pvcglue::Packages::AptUpdate.apply(minion)
      Pvcglue::Packages::AptUpgrade.apply(minion)
      Pvcglue::Packages::Swap.apply(minion)
      Pvcglue::Packages::Apt.apply(minion)
      Pvcglue::Packages::Firewall.apply(minion)
      Pvcglue::Packages::UnattendedUpgrades.apply(minion)
      Pvcglue::Packages::Users.apply(minion)
      Pvcglue::Packages::AuthorizedKeys.apply(minion)
      Pvcglue::Packages::DirBase.apply(minion)
      Pvcglue::Packages::DirShared.apply(minion)
      Pvcglue::Packages::Roles.apply(minion)


      # puts '='*175
    end

    # def build_manager!
    #   Pvcglue.logger.info('MANAGER') { "Building #{machine_name}" }
    #   Pvcglue.cloud.set_manager_as_project
    #   build!
    # end

    def provision!
      create! unless provisioned?
    end

    def provisioned?
      !!public_ip
    end

    def create!
      raise(Thor::Error, "#{cloud_provider.name} unknown") unless cloud_provider.name == 'digital-ocean'
      Pvcglue.logger.warn("Provisioning a machine for #{machine_name} on #{cloud_provider.name}...")

      # TODO:  Tags.  production, staging, load-balancer, web, worker, database, postgress, cache, memcache...
      name = machine_name
      size = capacity || cloud_provider.default_capacity
      image = cloud_provider.image
      region = cloud_provider.region
      # ap cloud_provider.initial_users
      # ap cloud_provider
      ssh_keys = cloud_provider.initial_users.map { |description, ssh_key| ssh_key }
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
      true
    end

    def has_role?(roles)
      return true if roles == 'all'
      !(Array(roles).map(&:to_sym) & roles_to_sym).empty?
    end

    def has_roles?(roles)
      has_role?(roles)
    end

    def roles_to_sym
      roles.map(&:to_sym)
    end

    def get_user(user_name)
      all_data.users.detect { |user| user.name == user_name }
    end

    def get_users_from_group(names)
      names = Array(names)
      users = []
      names.each do |name|
        if name =~ /\A==.*==\z/
          group = all_data.groups[name[2..-3]]
          # ap group
          users.concat(get_users_from_group(group))
        else
          users << get_user(name)
        end
      end
      users
    end

    def get_root_users
      get_users_from_group(root_users)
    end

    def get_users
      get_users_from_group(users)
    end

    def get_root_authorized_keys_data
      get_authorized_keys_data(get_root_users)
    end

    def get_users_authorized_keys_data
      get_authorized_keys_data(get_users)
    end

    def get_root_authorized_keys
      get_authorized_keys(get_root_users)
    end

    def get_users_authorized_keys
      get_authorized_keys(get_users)
    end

    def get_authorized_keys(users)
      keys = []
      users.each do |user|
        user.public_keys.each do |id, public_key|
          keys << public_key
        end
      end
      keys
    end
    def get_authorized_keys_data(users)
      data = []
      users.each do |user|
        user.public_keys.each do |id, public_key|
          line = %Q(environment="PVCGLUE_USER=#{user.name}" #{public_key})
          # line = %Q(command="export PVCGLUE_USER=#{id}" #{public_key})
          data << line
        end
      end
      data
    end
  end
end
