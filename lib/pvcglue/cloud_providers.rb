# TODO:  Refactor this, it's kinda messy :(
module Pvcglue
  class CloudProviders
    # REQUIRED_OPTIONS = []

    def self.init(provider_options)

      @options = provider_options
      @name = provider_options.name
      if provider_options.name == 'digital-ocean'
        Pvcglue.logger.debug("Digital Ocean provider initialized for '#{provider_options.name}'.")
        Pvcglue::CloudProviders::DigitalOcean.new(provider_options)
      elsif provider_options.name == 'linode'
        Pvcglue.logger.debug("Linode provider initialized for '#{provider_options.name}'.")
        Pvcglue::CloudProviders::Linode.new(provider_options)
      else
        raise(Thor::Error, "Cloud Provider '#{provider_options.name}' not supported, use 'manual' mode.")
      end
    end

    def name
      @name
    end

   def options
      @options
    end

    def validate_options!(options, required)
      errors = []
      required.each { |option_name| errors << "#{option_name} required" unless options[option_name] }
      raise("Errors:  #{errors.join(', ')}.") if errors.any?
    end

  end
end
