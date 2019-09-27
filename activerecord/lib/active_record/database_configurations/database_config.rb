# frozen_string_literal: true

module ActiveRecord
  class DatabaseConfigurations
    # ActiveRecord::Base.configurations will return either a HashConfig or
    # UrlConfig respectively. It will never return a DatabaseConfig object,
    # as this is the parent class for the types of database configuration objects.
    class DatabaseConfig # :nodoc:
      attr_reader :env_name, :spec_name

      def initialize(env_name, spec_name)
        @env_name = env_name
        @spec_name = spec_name
      end

      attr_writer :idle_timeout, :reaping_frequency, :pool

      def reaping_frequency
        @reaping_frequency&.to_f
      end

      def idle_timeout
        timeout = @idle_timeout&.to_f
        timeout if timeout && timeout > 0
      end

      # BYE!

      def checkout_timeout
        @checkout_timeout&.to_f
      end

      def pool
        @pool&.to_i
      end

      def config
        raise NotImplementedError
      end

      def adapter_method
        "#{adapter}_connection"
      end

      def database
        raise NotImplementedError
      end

      def adapter
        raise NotImplementedError
      end

      def replica?
        raise NotImplementedError
      end

      def migrations_paths
        raise NotImplementedError
      end

      def for_current_env?
        env_name == ActiveRecord::ConnectionHandling::DEFAULT_ENV.call
      end
    end
  end
end
