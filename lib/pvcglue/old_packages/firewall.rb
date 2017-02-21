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

# TODO:  add command line command for this
package 'update-firewall' do
  # quick update of firewall settings only.  Full bootstrap must be performed first.
  depends_on 'firewall-config'
  depends_on 'firewall-enabled'
end


# TODO:  add command line command for this
package 'firewall-status' do
  apply do
    run "ufw status verbose"
  end
end
