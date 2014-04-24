module Pvcglue
  class Packages
    def self.apply(package, nodes, user = 'deploy')
      # all_ips = []
      #
      # #allowed_ip_addresses = PVC_DATA[:application][:allowed_ip_addresses]
      # allowed_ip_addresses = {}
      #
      # allowed_ip_addresses.each { |_, ip| all_ips << ip } if allowed_ip_addresses
      #
      # nodes.each do |_, data|
      #   all_ips << data[:public_ip]
      #   all_ips << data[:private_ip] if data[:private_ip]
      # end
      #
      # #puts all_ips.inspect
      # #raise

      puts nodes.inspect

      nodes.each do |node, data|
        orca_node = ::Orca::Node.new(node, data[:public_ip], :user => user)
        ::Pvcglue.cloud.current_node = {node => data}
        begin
          ::Pvcglue.orca_suite.run(orca_node.name, package.to_s, :apply)
        ensure
          ::Pvcglue.cloud.current_node = nil
          ::Pvcglue.cloud.current_hostname = nil
        end
      end

    end
  end

  class OrcaSuite

    def self.init
      ::Orca.verbose(true)

      # Load orca extensions
      orca_file = File.join(File.dirname(__FILE__), 'all_the_things.rb')
      ENV['ORCA_FILE'] = orca_file
      suite = ::Orca::Suite.new
      suite.load_file(orca_file)

      Dir[File.join(Pvcglue::gem_dir, 'lib', 'pvcglue', 'packages', '*.rb')].each do |file|
        begin
          suite.load_file(file)
        rescue Exception => e
          puts "Error loading #{file}:  #{e.message}"
          raise
        end
        puts "Loading package:  #{file}"
      end
      puts "Loading packages done."
      suite
    end
  end

  def self.orca_suite
    @orca_suite ||= OrcaSuite.init
  end

end
