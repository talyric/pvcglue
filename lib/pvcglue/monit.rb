module Pvcglue
  class Monit
    def self.monitify
      Pvcglue.render_template('monit.app.monitrc.erb', monitrc_file_name)
    end

    def self.monitrc_file_name
      File.join(Pvcglue.configuration.application_dir, 'monitrc')
    end

   def self.worker_control_name
     "#{Pvcglue.cloud.app_and_stage_name}_worker_control"
    end

  end
end
