module Pvcglue
  class Packages
    def self.apply(package, context, nodes, user = 'deploy', package_filter = nil)
      # puts nodes.inspect
      orca_suite = OrcaSuite.init(package_filter)
      nodes.each do |node, data|
        old_current_node = ::Pvcglue.cloud.current_node_without_nil_check # this is being called recursively, so keep the original data...kinda a hack for now
        orca_node = ::Orca::Node.new(node, data[:public_ip], {user: user, port: Pvcglue.cloud.port_in_context(context)})
        # puts "#"*800
        # puts orca_node.name
        # puts package.to_s
        # puts "^"*80
        ::Pvcglue.cloud.current_node = {node => data}
        tries = 3
        begin
          begin
            # puts "="*800
            # puts orca_node.name
            # puts package.to_s
            # puts "^"*80
            orca_suite.run(orca_node.name, package.to_s, :apply)
          ensure
            # puts "-"*800
            # puts orca_node.name
            # puts package.to_s
            # puts "^"*80
            ::Pvcglue.cloud.current_node = old_current_node

            # ::Pvcglue.cloud.current_node = nil
            ::Pvcglue.cloud.current_hostname = nil
          end
        rescue Exception => e
          tries -= 1
          if tries > 0
            puts "\n"*10
            puts "*"*80
            puts "ERROR, retrying..."
            puts e.message
            puts "*"*80
            retry
          else
            puts "\n"*10
            puts "*"*80
            puts "ERROR, not retrying, fatal."
            puts e.message
            e.backtrace.each { |line| puts line }
            puts e.message
            puts node.inspect
            puts data.inspect
            puts "*"*80
          end
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
