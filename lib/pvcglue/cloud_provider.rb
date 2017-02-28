module Pvcglue
  class CloudProvider

    def initialize(host)
      super
      if host == 'digital-ocean'
        Pvcglue::CloudProvider::DigitalOcean.new
      elsif cloud_provider.name == 'linode'
        Pvcglue::CloudProvider::DigitalOcean.new
      else
        raise(Thor::Error, "Cloud Provider '#{cloud_provider.name}' not supported, use 'manual' mode.")
      end
    end

  end
end
