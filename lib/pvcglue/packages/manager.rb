package 'bootstrap-manager' do
  depends_on 'htop'
  #depends_on 'ufw'
  #depends_on 'deploy-user'
  #depends_on 'sshd-config'
  #depends_on 'firewall-config'
  #depends_on 'time-zone'
  depends_on 'pvcglue-user'
end

package 'pvcglue-user' do
  apply do
    home = '/home/pvcglue'
    pvc_manager = "#{home}/.pvc_manager"
    authorized_keys = "#{home}/.ssh/authorized_keys"

    sudo "useradd -d #{home} -m -U pvcglue"
    sudo "usermod -s /bin/bash pvcglue"
    sudo "mkdir -p #{pvc_manager} && chown pvcglue:pvcglue #{pvc_manager} && chmod 700 #{pvc_manager}"
    sudo "mkdir -p #{home}/.ssh && chown pvcglue:pvcglue #{home}/.ssh && chmod 700 #{home}/.ssh"
    copy_id = %Q[cat ~/.ssh/id_rsa.pub | ssh #{node.get(:user)}@#{node.host} "cat >> #{authorized_keys}"]
    `#{copy_id}`
    sudo "chown pvcglue:pvcglue #{authorized_keys} && chmod 600 #{authorized_keys}"
  end

  remove do
    raise "removing user not supported, yet.  It needs some 'Are you *really* sure?' stuff."
    #sudo "userdel -f pvcglue"
    #sudo "rm -rf /home/pvcglue"
  end

  validate do
    #sudo "userdel -f pvcglue"; sudo "rm -rf /home/pvcglue"; raise "User has been deleted"
    sudo('getent passwd pvcglue') =~ /^pvcglue:/
  end
end

package 'manager-push' do
  apply do
    if File.exists?(::Pvcglue.cloud.local_file_name)
      data = File.read(::Pvcglue.cloud.local_file_name)
      run(%Q[echo '#{data}' | tee #{::Pvcglue.cloud.manager_file_name}])
      run(%Q[chmod 600 #{::Pvcglue.cloud.manager_file_name}])
    else
      puts "Local file not found:  #{::Pvcglue.cloud.local_file_name}"
    end
  end
end

package 'manager-pull' do
  apply do
    data = run("cat #{::Pvcglue.cloud.manager_file_name}")
    if data.empty?
      puts "Remote manager file not found:  #{::Pvcglue.cloud.manager_file_name}"
    else
      File.write(::Pvcglue.cloud.local_file_name, data)
      puts "Saved as:  #{::Pvcglue.cloud.local_file_name}"
    end
  end
end

package 'manager-get-all' do
  apply do
    data = run("cat #{::Pvcglue.cloud.manager_file_name}")
    #puts "*"*80
    #puts data
    #puts "*"*80
    if data.empty?
      raise "Remote manager file not found:  #{::Pvcglue.cloud.manager_file_name}"
    else
      ::Pvcglue.cloud.data = JSON.parse(data)
    end
  end
end
