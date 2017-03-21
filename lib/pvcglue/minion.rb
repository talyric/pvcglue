module Pvcglue
  class Minion < SafeMash
    include Hashie::Extensions::Mash::SafeAssignment

    def build!
      minion = self # for readability

      Pvcglue.logger.info('BUILD') { "Building #{machine_name}" }
      Pvcglue.docs.level_1_roles(minion)

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

    def get_cloud_provider_options
      # Merge default and machine options
      options = machine_options.cloud_provider || ::SafeMash.new
      options.merge(default_cloud_provider)
    end

    def pvc_cloud_provider
      options = get_cloud_provider_options
      # raise("Unknown cloud provider '#{get_cloud_provider_name}'") unless get_cloud_provider_name
      @pvc_cloud_provider ||= Pvcglue::CloudProviders.init(options)
    end

    def create!
      Pvcglue.logger.warn("Provisioning a machine for #{machine_name} on #{pvc_cloud_provider.name}...")

      # TODO:  Tags.  production, staging, load-balancer, web, worker, database, postgress, cache, memcache...

      name = machine_name
      capacity = pvc_cloud_provider.options.capacity
      image = pvc_cloud_provider.options.image
      region = pvc_cloud_provider.options.region
      if pvc_cloud_provider.options.initial_users
        ssh_keys = pvc_cloud_provider.options.initial_users.map { |description, ssh_key| ssh_key }
      else
        ssh_keys = []
      end
      # backups = cloud_provider.backups.nil? ? true : cloud_provider.backups # default to true -- safety first!
      backups = pvc_cloud_provider.options.backups.nil? ? true : machine_options.cloud_provider.backups # default to true -- safety first!
      tags = pvc_cloud_provider.options.tags
      group = pvc_cloud_provider.options.group

      options = ::SafeMash.new(
          name: name,
          region: region,
          image: image,
          capacity: capacity,
          ssh_keys: ssh_keys,
          backups: backups,
          ipv6: false,
          tags: tags,
          group: group,
      )

      machine = pvc_cloud_provider.create(options)
      self.machine = machine
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
