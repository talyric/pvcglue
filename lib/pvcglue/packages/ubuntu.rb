apt_package 'htop'
apt_package 'ufw'
apt_package 'build-essential'
apt_package 'git', 'git-core'
apt_package 'libpq-dev'
apt_package 'libxml2', 'libxml2-dev'
apt_package 'libxslt', 'libxslt1-dev'
apt_package 'imagemagick'
apt_package 'curl'


#=======================================================================================================================
package 'apt-get-upgrade' do
#=======================================================================================================================
  apply do
    sudo "DEBIAN_FRONTEND=noninteractive apt-get update -y -qq"
    sudo "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y"
  end
end

#=======================================================================================================================
package 'reboot' do
#=======================================================================================================================
  apply do
    sudo "reboot"
  end
end

#=======================================================================================================================
package 'get-hostname' do
#=======================================================================================================================
  apply do
    Pvcglue.cloud.current_hostname = run('hostname')
  end

end

#=======================================================================================================================
package 'hostname' do
#=======================================================================================================================
  depends_on 'get-hostname'

  file({
           :template => Pvcglue.template_file_name('hosts.erb'),
           :destination => '/etc/hosts',
           :create_dirs => false,
           :permissions => 0644,
           :user => 'root',
           :group => 'root'
       }) do
    sudo('service hostname restart')
    hostname_f = run 'hostname -f'
    if Pvcglue.cloud.current_hostname != hostname_f
      raise "Hostname mismatch:  #{Pvcglue.cloud.current_hostname} != #{hostname_f}"
    end
  end

end

