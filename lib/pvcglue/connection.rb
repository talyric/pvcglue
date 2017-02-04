module Pvcglue
  # TODO:  Check ssh config
  ## https://puppet.com/blog/speed-up-ssh-by-reusing-connections
  #Host *
  #ControlMaster auto
  ##ControlPath ~/.ssh/sockets/%r@%h-%p
  #ControlPath ~/.ssh/%r@%h-%p
  #ControlPersist 600
  #
  # Way Faster!!!
  #

  class Connection
    def initialize(minion)
      @minion = minion
    end

    attr_accessor :minion
    attr_accessor :minion_state_data

    def file_exists?(user, file)
      # ssh?(user, '-t', "test -e #{file}").exitstatus == 0
      ssh?(user, '', "test -e #{file}").exitstatus == 0
    end

    def mkdir_p(user, remote_dir, owner = nil, group = nil, permissions = nil)
      ssh!(user, '', "mkdir -p #{remote_dir}")
      chown_chmod(user, remote_dir, owner, group, permissions)
    end

    def ssh_retry_wait(user, options, cmd, times, wait)
      tries = 0
      begin
        result = ssh?(user, options, cmd)
        unless result.exitstatus == 0
          Pvcglue.logger.info("Command `#{cmd}` failed, retrying...")
          sleep(wait)
        end
        tries += 1
        raise "Exceeded #{times} retries:  #{result.inspect}" if tries >= times
      end until result.exitstatus == 0
    end

    def ssh?(user, options, cmd)
      # TODO:  Refactor ssh? & ssh
      if cmd.include?("'") # TODO:  Quick fix, should be refactored to do proper escaping
        system_command?(%Q(ssh #{user}@#{minion.public_ip} #{options} "#{cmd}"))
      else
        system_command?(%Q(ssh #{user}@#{minion.public_ip} #{options} '#{cmd}'))
      end
    end

    def ssh!(user, options, cmd)
      result = ssh?(user, options, cmd)
      raise result.inspect unless result.exitstatus == 0
    end

    def system_command?(cmd)
      Pvcglue.logger.debug { cmd }
      system(cmd)
      Pvcglue.logger.debug { "exit_code=#{$?.exitstatus}" }
      $?
    end

    def system_command!(cmd)
      result = system_command?(cmd)
      raise result.inspect unless result.exitstatus == 0
    end

    def run_get_stdout(user, options, cmd)
      full_cmd = "ssh #{user}@#{minion.public_ip} #{options} '#{cmd}'"
      Pvcglue.logger.debug { full_cmd }
      result = `#{full_cmd}`
      Pvcglue.verbose? { result }
      Pvcglue.logger.debug { "exit_code=#{$?.to_i}" }
      result
    end

    def run_get_stdout!(user, options, cmd)
      result = run_get_stdout(user, options, cmd)
      raise $?.inspect unless $?.exitstatus == 0
      result
    end

    def run!(user, options, cmd)
      ssh!(user, options, cmd)
    end

    def run?(user, options, cmd)
      ssh?(user, options, cmd)
      # puts user.inspect
      # cmd = 'pwd'
      # full_command = "ssh root@#{minion.public_ip} '#{cmd}'"
      # full_command = "ssh root@#{minion.public_ip} 'ls -ahl'"
      # puts "running:  #{full_command}"
      # puts `#{full_command}`
      # 1.times do
      # 100.times do
      # puts "running:  #{full_command}"
      # puts `#{full_command}`
      # puts `ls -ahl ~/.ssh/config`
      # system %Q(ssh root@#{minion.public_ip} -o strictHostKeyChecking=no -t 'pwd')
      # ap system %Q(ssh root@#{minion.public_ip} 'test -e test')
      # ap system %Q(ssh root@#{minion.public_ip} -t 'test -e test')
      # ap $?
      # ap system %Q(ssh root@#{minion.public_ip} 'test -e .bashrc')
      # ap $?
      # ap file_exists?(:root, 'test')
      # ap file_exists?(:root, '.bashrc')
      # end
    end

    def read_from_file(user, file)
      tmp_file = Tempfile.new('pvc')
      begin
        download_file(user, file, tmp_file.path)
        data = tmp_file.read
        Pvcglue.verbose? { data }
      ensure
        tmp_file.close
        tmp_file.unlink # deletes the temp file
      end
      data
    end

    def write_to_file_from_template(user, template_file_name, file, owner = nil, group = nil, permissions = nil)
      Pvcglue.logger.debug { "Writing to #{file} from template '#{template_file_name}'" }
      template = Tilt.new(Pvcglue.template_file_name(template_file_name))
      data = template.render

      write_to_file(user, data, file, owner, group, permissions)
    end

    def write_to_file(user, data, file, owner = nil, group = nil, permissions = nil)
      tmp_file = Tempfile.new('pvc')
      begin
        tmp_file.write(data)
        tmp_file.flush
        upload_file(user, tmp_file.path, file, owner, group, permissions)
        Pvcglue.verbose? { data }
      ensure
        tmp_file.close
        tmp_file.unlink # deletes the temp file
      end
    end

    def download_file(user, remote_file, local_file)
      system_command!(%{scp #{user}@#{minion.public_ip}:#{remote_file} #{local_file}})
    end

    def upload_file(user, local_file, remote_file, owner = nil, group = nil, permissions = nil)
      system_command!(%{scp #{local_file} #{user}@#{minion.public_ip}:#{remote_file}})
      chown_chmod(user, remote_file, owner, group, permissions)
    end

    def chown_chmod(user, remote, owner, group, permissions = nil)
      unless owner.nil? && group.nil?
        raise('Invalid owner or group for chown') if owner.nil? || group.nil?
        ssh!(user, '', "chown #{owner}:#{group} #{remote}")
      end
      unless permissions.nil?
        ssh!(user, '', "chmod #{permissions} #{remote}")
      end
    end

    def file_matches?(user, data, remote_file)
      # NOTE:  This could be optimized
      return false unless file_exists?(user, remote_file)
      read_from_file(user, remote_file) == data
    end

    def rsync_up (user, options, local_source_dir, remote_destination_dir, mkdir = true)
      mkdir_p(user, remote_destination_dir) if mkdir
      cmd = ''
      # cmd += "mkdir -p #{remote_destination_dir} && "
      cmd += %(rsync #{options} #{local_source_dir}/ #{user}@#{minion.public_ip}:#{remote_destination_dir}/)
      # cmd = (%(rsync -rzv --exclude=maintenance.on --delete -e 'ssh -p #{Pvcglue.cloud.port_in_node_context}' #{source_dir}/ #{node.get(:user)}@#{node.host}:#{dest_dir}/))
      system_command!(cmd)
    end

  end
end
