module Pvcglue
  class Packages
    def self.apply(package, nodes, user = 'deploy')
      ::Orca.verbose(true)

      # Load orca extensions
      orca_file = File.join(File.dirname(__FILE__), 'all_the_things.rb')
      ENV['ORCA_FILE'] = orca_file
      suite = ::Orca::Suite.new
      suite.load_file(orca_file)

      Dir[File.join(Pvcglue::gem_dir, 'lib', 'pvcglue', 'packages', '*.rb')].each { |file| puts "#{file}******"; suite.load_file(file) }

      all_ips = []

      #allowed_ip_addresses = PVC_DATA[:application][:allowed_ip_addresses]
      allowed_ip_addresses = {}

      allowed_ip_addresses.each { |_, ip| all_ips << ip } if allowed_ip_addresses

      nodes.each do |_, data|
        all_ips << data[:public_ip]
        all_ips << data[:private_ip] if data[:private_ip]
      end

      #puts all_ips.inspect
      #raise

      nodes.each do |server, data|
        orca_node = ::Orca::Node.new(server, data[:public_ip], :user => user, server: server, server_data: data, allowed_ip_addresses: all_ips)
        suite.run(orca_node.name, package.to_s, :apply)
      end

    end
  end
end
