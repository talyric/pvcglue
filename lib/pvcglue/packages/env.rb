package 'env-initialized' do
  apply do
    ::Pvcglue::Env.initialize_stage_env
  end
end

package 'env-get-stage' do
  apply do
    data = run("cat #{::Pvcglue::Env.stage_env_file_name}")
    ::Pvcglue.cloud.stage_env = TOML.parse(data)
  end

end

package 'env-set-stage' do
  apply do
    data = TOML.dump(Pvcglue.cloud.stage_env)
    run(%Q[echo '#{data}' | tee #{::Pvcglue::Env.stage_env_file_name} && chmod 600 #{::Pvcglue::Env.stage_env_file_name}])
  end

end

package 'deploy-to-base' do
  validate do
    stat = run("stat --format=%U:%G:%a #{Pvcglue.cloud.deploy_to_app_shared_dir}").strip
    stat == 'deploy:deploy:2775'
  end

  apply do
    # Reference: http://capistranorb.com/documentation/getting-started/authentication-and-authorisation/
    run "mkdir -p #{Pvcglue.cloud.deploy_to_app_shared_dir}"
    # sudo "chown deploy:deploy #{ENV['PVC_DEPLOY_TO_BASE']}"
    run "umask 0002 && chmod g+s #{Pvcglue.cloud.deploy_to_app_shared_dir}"
  end
end

package 'app-env' do
  depends_on 'deploy-to-base'
  depends_on 'app-env-file'
end

package 'app-env-file' do
  depends_on 'env-initialized'

  file({
           :template => Pvcglue.template_file_name('web.env.erb'),
           :destination => Pvcglue.cloud.env_file_name,
           :create_dirs => true,
           :permissions => 0640 # TODO:  Double check permissions
       }) do
    run("touch #{Pvcglue.cloud.restart_txt_file_name}")
  end

end


package 'env-push' do
  apply do
    if File.exists?(::Pvcglue.cloud.env_local_file_name)
      data = File.read(::Pvcglue.cloud.env_local_file_name)
      run(%Q[echo '#{data}' | tee #{::Pvcglue::Env.stage_env_file_name}])
      run(%Q[chmod 600 #{::Pvcglue::Env.stage_env_file_name}])
    else
      puts "Local env file not found:  #{::Pvcglue.cloud.env_local_file_name}"
    end
  end
end

package 'env-pull' do
  apply do
    data = run("cat #{::Pvcglue::Env.stage_env_file_name}")
    if data.empty?
      puts "Remote env file not found:  #{::Pvcglue::Env.stage_env_file_name}"
    else
      File.write(::Pvcglue.cloud.env_local_file_name, data)
      puts "Saved as:  #{::Pvcglue.cloud.env_local_file_name}"
    end
  end
end

