package 'bootstrap-ubuntu-12-04' do

  apply do
    puts "BOOTSTRAP GOT HERE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  end
  depends_on 'htop'
  #depends_on 'ufw'
  #depends_on 'deploy-user'
  #depends_on 'sshd-config'
  #depends_on 'firewall-config'
  #depends_on 'time-zone'
end

apt_package 'htop'
apt_package 'ufw'
