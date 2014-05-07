require 'toml'
apt_package 'htop'
apt_package 'ufw'

package 'bootstrap-manager' do
  # TODO: firewall and ssh port config
  #depends_on 'time-zone'
  depends_on 'htop'
  # depends_on 'ufw'
  #depends_on 'deploy-user'
  #depends_on 'sshd-config'
  #depends_on 'firewall-config'
  depends_on 'pvcglue-user'
  depends_on 'manager-copy-id'
end

package 'pvcglue-user' do
  apply do
    # Local variables used to improve readability of bash commands :)
    user_name = Pvcglue::Manager.user_name
    home_dir = Pvcglue::Manager.home_dir
    manager_dir = Pvcglue::Manager.manager_dir
    ssh_dir = Pvcglue::Manager.ssh_dir

    sudo "useradd -d #{home_dir} -m -U #{user_name}"
    sudo "usermod -s /bin/bash #{user_name}"
    sudo "mkdir -p #{manager_dir} && chown #{user_name}:#{user_name} #{manager_dir} && chmod 700 #{manager_dir}"
    sudo "mkdir -p #{ssh_dir} && chown #{user_name}:#{user_name} #{ssh_dir} && chmod 700 #{ssh_dir}"
  end

  remove do
    raise "removing user not supported, yet.  It needs some 'Are you *really* sure?' stuff."
    # user_name = Pvcglue::Manager.user_name
    # home_dir = Pvcglue::Manager.home_dir
    #sudo "userdel -f #{user_name}"
    #sudo "rm -rf #{home_dir}"
  end

  validate do
    user_name = Pvcglue::Manager.user_name
    # home_dir = Pvcglue::Manager.home_dir
    #sudo "userdel -f #{user_name}"; sudo "rm -rf #{home_dir}"; raise "User has been deleted"
    sudo("getent passwd #{user_name}") =~ /^#{user_name}:/
  end
end

package 'manager-copy-id' do
  validate do
    authorized_keys_file_name = Pvcglue::Manager.authorized_keys_file_name
    user_key = `cat ~/.ssh/id_rsa.pub`.strip
    auth = run("cat #{authorized_keys_file_name}")
    auth.include?(user_key)
  end

  apply do
    authorized_keys_file_name = Pvcglue::Manager.authorized_keys_file_name
    user_name = Pvcglue::Manager.user_name
    copy_id = %Q[cat ~/.ssh/id_rsa.pub | ssh #{node.get(:user)}@#{node.host} "cat >> #{authorized_keys_file_name}"]
    system "#{copy_id}"
    sudo "chown #{user_name}:#{user_name} #{authorized_keys_file_name} && chmod 600 #{authorized_keys_file_name}"
  end
end

package 'manager-push' do
  apply do
    if File.exists?(::Pvcglue.cloud.local_file_name)
      data = File.read(::Pvcglue.cloud.local_file_name)
      run(%Q[echo '#{data}' | tee #{::Pvcglue::Manager.manager_file_name}])
      run(%Q[chmod 600 #{::Pvcglue::Manager.manager_file_name}])
    else
      puts "Local file not found:  #{::Pvcglue.cloud.local_file_name}"
    end
  end
end

package 'manager-pull' do
  apply do
    data = run("cat #{::Pvcglue::Manager.manager_file_name}")
    if data.empty?
      puts "Remote manager file not found:  #{::Pvcglue::Manager.manager_file_name}"
    else
      File.write(::Pvcglue.cloud.local_file_name, data)
      puts "Saved as:  #{::Pvcglue.cloud.local_file_name}"
    end
  end
end

package 'manager-get-config' do
  apply do
    data = run("cat #{::Pvcglue::Manager.manager_file_name}")
    #puts "*"*80
    #puts data
    #puts "*"*80
    if data.empty?
      raise "Remote manager file not found:  #{::Pvcglue::Manager.manager_file_name}"
    else
      ::Pvcglue.cloud.data = TOML.parse(data)
    end
  end
end

