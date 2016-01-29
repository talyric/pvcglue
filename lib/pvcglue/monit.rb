module Pvcglue
  class Monit
    def self.monitify
      Pvcglue.render_template('monit.app.monitrc.erb', monitrc_file_name)
    end

    def self.monitrc_file_name
      File.join(Pvcglue.configuration.application_dir, "monitrc.#{Pvcglue.cloud.stage_name}")
    end

    def self.worker_control_name
      "#{Pvcglue.cloud.app_and_stage_name}_worker_control"
    end

    def self.delayed_job_queue_name(n)
      "#{Pvcglue.cloud.app_and_stage_name}_delayed_job.#{n}"
    end

    def self.resque_queue_name(n)
      "#{Pvcglue.cloud.app_and_stage_name}_resque_worker.#{n}"
    end

    def self.resque_pid_file_name(n)
      "#{Pvcglue.cloud.deploy_to_app_shared_pids_dir}/resque_worker.#{n}.pid"
    end

    def self.safe_name(s)
      s.gsub(/\W/, '_')
    end

  end
end
