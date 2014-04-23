# package 'firewall-config' do
#   apply do
#     public_rules = ''
#     public_rules += 'ufw allow 80 && ufw allow 443 && ' if node.server_data['allow_public_access']
#     public_rules += "ufw allow #{ENV['PVC_SSH_ALLOW_FROM_ALL']} && " if ENV['PVC_SSH_ALLOW_FROM_ALL'].present?
#     #puts public_rules + "<========================"
#     pvc_rules = node.allowed_ip_addresses.map { |a| "ufw allow from #{a}" }.join(' && ')
#     # TODO:  remove hardcoded IP and add to configuration
#     ufw_config = "yes | ufw reset && #{public_rules}#{pvc_rules} && ufw allow from 68.189.112.146 && yes | ufw enable && ufw status verbose"
#     #puts ufw_config
#     run (ufw_config)
#     #run "yes | ufw reset"
#   end
# end

# Reference:  http://manpages.ubuntu.com/manpages/precise/en/man8/ufw-framework.8.html
package 'firewall-config' do

  file({
           :template => Pvcglue.template_file_name('ufw.rules6.erb'),
           :destination => '/lib/ufw/user6.rules',
           :create_dirs => false,
           :permissions => 0640,
           :user => 'root',
           :group => 'root'
       }) {  }

  file({
           :template => Pvcglue.template_file_name('ufw.rules.erb'),
           :destination => '/lib/ufw/user.rules',
           :create_dirs => false,
           :permissions => 0640,
           :user => 'root',
           :group => 'root'
       }) { sudo('service ufw restart') }

end

package 'firewall-enabled' do
  validate do
    result = sudo('ufw status verbose')
    result =~ /Status: active/ && result =~ /Default: deny \(incoming\), allow \(outgoing\)/
  end

  apply do
    sudo('ufw --force enable')
  end
end


#=======================================================================================================================
package 'update-firewall' do
#=======================================================================================================================
  # quick update of firewall settings only.  Full bootstrap must be performed first.
  depends_on 'firewall-config'
  depends_on 'firewall-enabled'
end


#=======================================================================================================================
package 'firewall-status' do
#=======================================================================================================================
  apply do
    run "ufw status verbose"
  end
end
