package 'time-zone' do
  # http://hacksforge.com/How-to-change-time-zone-in-Ubuntu-Linux.html

  file({
           :template => Pvcglue.template_file_name('timezone.erb'),
           :destination => '/etc/timezone',
           :create_dirs => false,
           :permissions => 0644,
           :user => 'root',
           :group => 'root'
       }) do
    sudo %Q[dpkg-reconfigure --frontend noninteractive tzdata]
    sudo %Q[service cron restart]
  end

end

