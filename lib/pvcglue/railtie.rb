require 'pvcglue'
require 'rails'
module Pvcglue
  class Railtie < Rails::Railtie
    railtie_name :pvcglue

    rake_tasks do
      load "tasks/db_utils.rake"
    end
  end
end