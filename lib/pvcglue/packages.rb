module Pvcglue
  class Packages
    def self.apply(package, nodes, user = 'deploy', package_filter = nil)
      # puts nodes.inspect
      orca_suite = OrcaSuite.init(package_filter)
      nodes.each do |node, data|
        orca_node = ::Orca::Node.new(node, data[:public_ip], :user => user)
        ::Pvcglue.cloud.current_node = {node => data}
        begin
          orca_suite.run(orca_node.name, package.to_s, :apply)
        ensure
          ::Pvcglue.cloud.current_node = nil
          ::Pvcglue.cloud.current_hostname = nil
        end
      end
    end
  end

  class OrcaSuite

    def self.init(package_filter)
      ::Orca.verbose(package_filter != 'manager') # show details for all packages except manager, for now

      # Load orca extensions
      orca_file = File.join(File.dirname(__FILE__), 'all_the_things.rb')
      ENV['ORCA_FILE'] = orca_file
      suite = ::Orca::Suite.new
      suite.load_file(orca_file)
      packages_loaded = []

      Dir[File.join(Pvcglue::gem_dir, 'lib', 'pvcglue', 'packages', '*.rb')].each do |file|
        # package filter is used to load the manager package by itself when stage is not specified
        next if package_filter && package_filter != File.basename(file, ".rb")
        begin
          suite.load_file(file)
        rescue Exception => e
          puts "Error loading #{file}:  #{e.message}"
          raise
        end
        packages_loaded << File.basename(file, ".rb")
      end
      puts "Packages loaded: #{packages_loaded.sort.join(' ')}."
      suite
    end
  end

end
