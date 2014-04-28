package 'env-initialized' do
  ::Pvcglue::Env.initialize_stage_env
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
    run("ls -ahl #{Pvcglue.cloud.deploy_to_base_dir}") != ''
  end

  apply do
    # Reference: http://capistranorb.com/documentation/getting-started/authentication-and-authorisation/
    run "mkdir -p #{Pvcglue.cloud.deploy_to_base_dir}"
    # sudo "chown deploy:deploy #{ENV['PVC_DEPLOY_TO_BASE']}"
    run "umask 0002 && chmod g+s #{Pvcglue.cloud.deploy_to_base_dir}"
  end
end

package 'app-env' do
  depends_on 'deploy-to-base'
  # don't forget to sort first

  file({
           :template => Pvcglue.template_file_name('web.env.erb'),
           :destination => Pvcglue.cloud.env_file_name,
           :create_dirs => true,
           :permissions => 0640 # TODO:  Double check permissions
       }) do
    sudo('service nginx restart')
    run("touch #{Pvcglue.cloud.restart_txt_file_name}")
  end

end
