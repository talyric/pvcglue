package 'rvm' do
  depends_on 'curl'
  depends_on 'rvm-bashrc'

  validate do
    run('type rvm | head -n 1') =~ /rvm is a function/
  end

  apply do
    run 'gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3'
    run '\curl -sSL https://get.rvm.io | bash -s stable --with-default-gems="bundler"'
    run "rvm requirements"
  end

  remove do
    run 'yes "yes" | rvm implode'
  end
end

package 'rvm-bashrc' do
  file({
           :template => Pvcglue.template_file_name('web.bashrc.erb'),
           :destination => '/home/deploy/.bashrc',
           :create_dirs => false,
           :permissions => 0644,
           :user => 'deploy',
           :group => 'deploy'
       })
end

package 'gem' do
  depends_on 'rvm-ruby'
  action 'exists' do |gem_name|
    run("gem list -i #{gem_name}") =~ /true/
  end
  action 'install' do |gem_name|
    sudo "gem install #{gem_name} --no-ri --no-rdoc"
  end
  action 'uninstall' do |gem_name|
    sudo "gem uninstall #{gem_name} -x -a"
  end
end

package 'bundler' do
  depends_on 'gem'
  apply { trigger 'gem:install', 'bundler' }
  remove { trigger 'gem:remove', 'bundler' }
  validate { trigger 'gem:exists', 'bundler' }
end

package 'rvm-ruby' do
  depends_on 'rvm'

  validate do
    run('rvm list strings') =~ /#{Pvcglue.configuration.ruby_version.gsub('.', '\.')}/
  end

  apply do
    run "rvm install #{Pvcglue.configuration.ruby_version}"
    # run "rvm --default use 2.0.0"
  end

  remove do
    run "rvm remove --archive --gems #{Pvcglue.configuration.ruby_version}"
  end

end

package 'no-rdoc' do
  file({
           :template => Pvcglue.template_file_name('gemrc.erb'),
           :destination => '/home/deploy/.gemrc',
           :create_dirs => false
       })
end

