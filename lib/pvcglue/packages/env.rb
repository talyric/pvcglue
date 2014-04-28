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

