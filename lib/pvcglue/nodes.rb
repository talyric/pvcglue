module Pvcglue
  class Nodes
    def self.build(roles_filter)
      Pvcglue::Nodes.new(roles_filter).run
    end

    def initialize(roles_filter)
      @roles_filter = roles_filter
    end

    def apply_role?(role)
      @roles_filter == 'all' || role == @roles_filter
    end
    
    def run
      puts "This is where it should configure the nodes for #{@roles_filter}.  :)"

      %w(lb db web caching redis).each do |role|
        if apply_role?(role)
          Pvcglue::Packages.apply(role.to_sym, :build, Pvcglue.cloud.nodes_in_stage(role))
        end
      end

      Pvcglue::Capistrano.capify

    end

  end
end
