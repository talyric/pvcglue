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

    def file_exists?(user, file)
      ssh(user, '-t', "test -e #{file}").exitstatus == 0
    end

    def ssh(user, options, cmd)
      system_command('SSH', %Q(ssh #{user}@#{minion.public_ip} #{options} '#{cmd}'))
    end

    def system_command(description, cmd)
      Pvcglue.logger.debug(description) { cmd }
      system(cmd)
      Pvcglue.logger.debug(description) { "exit_code=#{$?.exitstatus}" }
      $?
    end

    def system_command!(description, cmd)
      result = system_command(description, cmd)
      raise result.inspect unless result.exitstatus == 0
    end

    def run(user, cmd)
      ssh(user, '', cmd)
      # puts user.inspect
      cmd = 'pwd'
      # full_command = "ssh root@#{minion.public_ip} '#{cmd}'"
      full_command = "ssh root@#{minion.public_ip} 'ls -ahl'"
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
      ensure
        tmp_file.close
        tmp_file.unlink # deletes the temp file
      end
      data
    end

    def write_to_file(user, data, file, owner = nil, group = nil, permissions = nil)
      tmp_file = Tempfile.new('pvc')
      begin
        tmp_file.write(data)
        tmp_file.flush
        upload_file(user, tmp_file.path, file, owner, group, permissions)
      ensure
        tmp_file.close
        tmp_file.unlink # deletes the temp file
      end
    end

    def download_file(user, remote_file, local_file)
      system_command!('DOWNLOAD', %{scp #{user}@#{minion.public_ip}:#{remote_file} #{local_file}})
    end

    def upload_file(user, local_file, remote_file, owner = nil, group = nil, permissions = nil)
      system_command!('UPLOAD', %{scp #{local_file} #{user}@#{minion.public_ip}:#{remote_file}})
      # TODO:  Set owner, group and permissions, if specified
      raise 'Not implemented, yet!' unless owner.nil? && group.nil? && permissions.nil?
    end
  end
end
