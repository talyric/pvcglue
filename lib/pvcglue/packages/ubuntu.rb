# apt_package 'htop' # moved to manager
# apt_package 'ufw' # moved to manager
apt_package 'build-essential'
apt_package 'git', 'git-core'
apt_package 'libpq-dev'
apt_package 'libxml2', 'libxml2-dev'
apt_package 'libxslt', 'libxslt1-dev'
apt_package 'imagemagick'
apt_package 'curl'

package 'swap' do
  # https://www.digitalocean.com/community/articles/how-to-add-swap-on-ubuntu-12-04
  depends_on 'swap-fstab'

  validate do
    # TODO:  This may be brittle
    # Ex:  "Filename\t\t\t\tType\t\tSize\tUsed\tPriority\n/swapfile                               file\t\t524284\t306372\t-1\n"
    result = sudo("swapon -s")
    data = result.split("\n").last.split("\t")[2]
    # sudo("swapon -s") =~ /\/swapfile                               file		#{Pvcglue.cloud.swapfile_size}	0	-1/
    megs = (data.to_f / 1024).round
    puts megs.inspect
    puts Pvcglue.cloud.swapfile_size.inspect
    megs == Pvcglue.cloud.swapfile_size
  end

  apply do
    sudo("swapoff -a")
    sudo("rm /swapfile")
    sudo("fallocate -l #{Pvcglue.cloud.swapfile_size}M /swapfile")
    # sudo("dd if=/dev/zero of=/swapfile bs=1024 count=#{Pvcglue.cloud.swapfile_size}k")
    sudo("sudo chown root:root /swapfile && sudo chmod 0600 /swapfile")
    sudo("echo 10 | sudo tee /proc/sys/vm/swappiness")
    sudo("echo vm.swappiness = 10 | sudo tee -a /etc/sysctl.conf")
    sudo("mkswap /swapfile")
    sudo("swapon /swapfile")
  end
end

package 'swap-fstab' do
  validate do
    sudo("cat /etc/fstab") =~ /\/swapfile/
  end

  apply do
    sudo(%Q[echo '/swapfile       none    swap    sw      0       0' | sudo tee -a /etc/fstab])
  end
end

package 'apt-get-upgrade' do
  apply do
    sudo "DEBIAN_FRONTEND=noninteractive apt-get update -y -qq"
    sudo "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y"
  end
end
=begin
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
proc            /proc           proc    nodev,noexec,nosuid 0       0
# / was on /dev/vda1 during installation
UUID=b96601ba-7d51-4c5f-bfe2-63815708aabd /               ext4    noatime,errors=remount-ro 0       1
=end
package 'reboot' do
  apply do
    sudo "reboot"
  end
end

package 'get-hostname' do
  apply do
    Pvcglue.cloud.current_hostname = run('hostname')
  end

end

package 'hostname' do
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

