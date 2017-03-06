module Pvcglue
  class Pvcify
    def self.run
      # Pvcglue::Monit.monitify
      Pvcglue::Capistrano.capify
      Pvcglue::Db.configure_database_yml
    end
  end
end
