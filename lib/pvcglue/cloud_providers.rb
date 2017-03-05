module Pvcglue
  class CloudProviders
    REQUIRED_OPTIONS = []

    def self.init(cloud_provider)
      @name = cloud_provider.name
      if cloud_provider.name == 'digital-ocean'
        Pvcglue.logger.debug("Digital Ocean provider initialized for '#{cloud_provider.name}'.")
        Pvcglue::CloudProviders::DigitalOcean.new
      elsif cloud_provider.name == 'linode'
        Pvcglue.logger.debug("Linode provider initialized for '#{cloud_provider.name}'.")
        Pvcglue::CloudProviders::Linode.new
      else
        raise(Thor::Error, "Cloud Provider '#{cloud_provider.name}' not supported, use 'manual' mode.")
      end
    end

    def name
      @name
    end

    def validate_options!(options)
      errors = []
      REQUIRED_OPTIONS.each { |option_name| errors << "#{option_name} required" unless options[option_name] }
      raise("Errors:  #{errors.join(', ')}.") if errors.any?
    end

  end
end
