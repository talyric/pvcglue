module Pvcglue
  class PvcManager
    def initialize
      puts "init here..."
    end

    def bootstrap
      Pvcglue::Packages.apply('bootstrap-manager'.to_sym, {manager: {public_ip: '192.241.171.127'}}, 'root')
    end
  end
end
