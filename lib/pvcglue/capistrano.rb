module Pvcglue
  class Capistrano
    # TODO:  Add requirements to gem file:  capistrano-rails, etc.
    def self.capify
      Pvcglue.render_template('capfile.erb', capfile_file_name)
      Pvcglue.render_template('deploy.rb.erb', common_deploy_file_name)
      Pvcglue.render_template('stage-deploy.rb.erb', stage_deploy_file_name)
    end

    def self.capfile_file_name
      File.join(Pvcglue.configuration.application_dir, 'Capfile')
    end

    def self.application_config_dir
      File.join(Pvcglue.configuration.application_dir, 'config')
    end

    def self.common_deploy_file_name
      File.join(application_config_dir, 'deploy.rb')
    end

    def self.stage_deploy_dir
      File.join(application_config_dir, 'deploy')
    end

    def self.stage_deploy_file_name
      `mkdir -p #{stage_deploy_dir}`
      File.join(stage_deploy_dir, "#{Pvcglue.cloud.stage_name_validated}.rb")
    end

    def self.deploy
      system("cap #{Pvcglue.cloud.stage_name} deploy")
    end
  end
end
