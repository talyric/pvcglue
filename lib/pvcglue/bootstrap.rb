module Pvcglue
  class Bootstrap
    def self.run(roles)
      # puts "This is where it should bootstrap #{Pvcglue.cloud.stage_name}.  :)"
      Pvcglue::Packages.apply('bootstrap'.to_sym, Pvcglue.cloud.nodes_in_stage(roles), 'root')
    end
  end
end
