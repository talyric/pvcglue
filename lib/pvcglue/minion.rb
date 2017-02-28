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
      public_ip.present?
    end

    def create!
      provider = Pvcglue::CloudProvider.new(machine_options.cloud_provider || cloud_provider.name)

      Pvcglue.logger.warn("Provisioning a machine for #{machine_name} on #{cloud_provider.name}...")

      # TODO:  Tags.  production, staging, load-balancer, web, worker, database, postgress, cache, memcache...
      name = machine_name
      size = machine_options.capacity || cloud_provider.default_capacity
      image = cloud_provider.image
      region = machine_options.region || cloud_provider.region
      ssh_keys = cloud_provider.initial_users.map { |description, ssh_key| ssh_key }
      # backups = cloud_provider.backups.nil? ? true : cloud_provider.backups # default to true -- safety first!
      backups = machine_options.backups.nil? ? true : machine_options.backups # default to true -- safety first!
      tags = machine_options.tags
      group = machine_options.group

      options = ::SafeMash.new(
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
          tags: tags,
          group: group,
      )

      droplet = provider.create(options)
      self.droplet = droplet
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

    def minion_manager?
      has_role?('manager')
    end

    def get_user(user_name)
      Pvcglue.cloud.data.users.detect { |user| user.name == user_name }
    end

    def get_users_from_group(names)
      names = Array(names)
      users = []
      names.each do |name|
        if name =~ /\A==.*==\z/
          group = Pvcglue.cloud.data.groups[name[2..-3]]
          # ap group
          users.concat(get_users_from_group(group))
        else
          users << get_user(name)
        end
      end
      users
    end

    def get_root_users
      if minion_manager?
        get_users_from_group('==manager_root_users==')
      else
        get_users_from_group('==lead_developers==')
      end
    end

    def get_users
      if minion_manager?
        get_users_from_group('==manager_users==')
      else
        get_users_from_group('==developers==')
      end
    end

    def get_root_authorized_keys_data
      get_authorized_keys_data(get_root_users)
    end

    def get_users_authorized_keys_data
      get_authorized_keys_data(get_users)
    end

    # def get_root_authorized_keys
    #   get_authorized_keys(get_root_users)
    # end
    #
    # def get_users_authorized_keys
    #   get_authorized_keys(get_users)
    # end
    #
    # def get_authorized_keys(users)
    #   keys = []
    #   users.each do |user|
    #     user.public_keys.each do |id, public_key|
    #       keys << public_key
    #     end
    #   end
    #   keys
    # end

    def get_github_authorized_keys(user)
      return [] unless user.github_user_name.present?
      uri = URI("https://github.com/#{user.github_user_name}.keys")
      Net::HTTP.get(uri).split("\n")
    end

    def get_authorized_keys_data(users)
      data = []
      users.each do |user|
        keys = []
        keys += user.public_keys.values if user.public_keys
        keys += get_github_authorized_keys(user)
        keys.each do |public_key|
          line = %Q(environment="PVCGLUE_USER=#{user.name}" #{public_key})
          # line = %Q(command="export PVCGLUE_USER=#{id}" #{public_key})
          data << line
        end
      end
      data
    end

    # def update_from(another_minion)
    #   self.private_ip = another_minion.private_ip
    #   self.public_ip = another_minion.public_ip
    #   self.cloud_id = another_minion.cloud_id
    # end
  end
end
