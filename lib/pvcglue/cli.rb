require 'thor'
require 'pvcglue'

module Pvcglue
  class CLI < Thor

    desc "version", "show the version of PVC..."

    def version
      puts Pvcglue::Version.version
    end

  end
end