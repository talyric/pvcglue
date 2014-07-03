require 'pvcglue'
require 'rails'
module Pvcglue
  class Railtie < Rails::Railtie
    railtie_name :pvcglue

    rake_tasks do
      ap __FILE__
      load "tasks/pvc_db_utils.rake"
    end
  end
end