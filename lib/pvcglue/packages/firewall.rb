package 'firewall-config' do
  apply do
    public_rules = ''
    public_rules += 'ufw allow 80 && ufw allow 443 && ' if node.server_data['allow_public_access']
    public_rules += "ufw allow #{ENV['PVC_SSH_ALLOW_FROM_ALL']} && " if ENV['PVC_SSH_ALLOW_FROM_ALL'].present?
    #puts public_rules + "<========================"
    pvc_rules = node.allowed_ip_addresses.map { |a| "ufw allow from #{a}" }.join(' && ')
    # TODO:  remove hardcoded IP and add to configuration
    ufw_config = "yes | ufw reset && #{public_rules}#{pvc_rules} && ufw allow from 68.189.112.146 && yes | ufw enable && ufw status verbose"
    #puts ufw_config
    run (ufw_config)
    #run "yes | ufw reset"
  end
end

#=======================================================================================================================
package 'update-firewall' do
#=======================================================================================================================
  depends_on 'firewall-config'
end


#=======================================================================================================================
package 'firewall-status' do
#=======================================================================================================================
  apply do
    run "ufw status verbose"
  end
end
