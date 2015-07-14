package 'monit-web' do
  depends_on 'monit-bootstrap'

  apply do
    #include /etc/monit/conf.d/*
    sudo "ln -s #{Pvcglue.cloud.deploy_to_app_current_dir}/monitrc /etc/monit/conf.d/#{Pvcglue.cloud.app_name}_#{Pvcglue.cloud.stage_name}.conf"
    # sudo 'service monit restart'
  end
end

