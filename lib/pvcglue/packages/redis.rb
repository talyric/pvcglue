module Pvcglue
  class Packages
    class Redis < Pvcglue::Packages

      def installed?
        get_minion_state
      end

      def install!
        docs.set_item(
          heading: 'Redis',
          body: 'Set the recommended persistence and memory settings.',
          notes: [
            'If multiple applications use the same virtual machine, set a unique database number (0-15) for each one `REDIS_URL=redis://<redis_private_ip>:6379/<number>`'
          ],
          cheatsheet: [
            'System Level Status(run on Redis server):  sudo systemctl status redis',
            'Redis Info (run on Redis server):  redis-cli info',
            'Redis Status (run on Redis server):  redis-cli --stat',
            'Monitor Redis Commands (run on Redis server):  redis-cli monitor',
            'Latency (run on Redis server):  redis-cli --latency',
            'Intrinsic Latency (run on Redis server):  redis-cli --intrinsic-latency 10',
            'Ping Redis (run from web or worker):  redis-cli -h xxx.xxx.xxx.xxx ping',
            'Redis Status (run from web or worker):  redis-cli -h xxx.xxx.xxx.xxx --stat',
            'Latency (run from web or worker):  redis-cli -h xxx.xxx.xxx.xxx --latency',
            'Latency Dist (run from web or worker):  redis-cli -h xxx.xxx.xxx.xxx --latency-dist',
          ],
          references: [
            '[CLI Reference]https://redis.io/topics/rediscli',
            'https://www.linode.com/docs/databases/redis/deploy-redis-on-ubuntu-or-debian',
            'https://redis.io/topics/faq',
            'http://serverfault.com/questions/485798/cent-os-how-do-i-turn-off-or-reduce-memory-overcommitment-and-is-it-safe-to-do',
            'https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-redis-on-ubuntu-16-04',
            'http://stackoverflow.com/questions/21795340/linux-install-redis-cli-only',
          ]
        ) do
          # Persistence
          connection.write_to_file_from_template(:root, 'redis.conf.erb', '/etc/redis/redis.conf')
          connection.run!(:root, '', 'service redis-server restart')

          # Memory management
          connection.run!(:root, '', 'sysctl vm.overcommit_memory=1') # Not sure if this is necessary if doing `sysctl -p`
          connection.write_to_file_from_template(:root, 'sysctl.conf.erb', '/etc/sysctl.conf')
          connection.run!(:root, '', 'sysctl -p')
        end

        set_minion_state
      end

      def post_install_check?
        redis_info = connection.run_get_stdout!(user_name, '', 'redis-cli info')
        no_eviction = redis_info =~ /maxmemory_policy:noeviction/
        aof_enabled = redis_info =~ /aof_enabled:1/
        get_minion_state && no_eviction && aof_enabled
      end
    end
  end
end
