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

      %w(lb db web caching).each do |role|
        if apply_role?(role)
          Pvcglue::Packages.apply(role.to_sym, Pvcglue.cloud.nodes_in_stage(role))
        end
      end

      # puts ("-"*80)+"group: load-balancer"
      # run_orca(:lb, stage_data[:nodes][:lb])
      #
      # puts ("-"*80)+"group: db"
      # run_orca(:db, stage_data[:nodes][:db]) # Setup db before web
      #
      # puts ("-"*80)+"group: web"
      # run_orca(:web, stage_data[:nodes][:web])
      #
      # puts ("-"*80)+"group: caching"
      # run_orca(:caching, stage_data[:nodes][:caching])

      update_capistrano_config

    end

  end
end
