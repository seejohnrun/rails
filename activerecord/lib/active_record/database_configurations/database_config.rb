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

      def initialize_dup(original)
        @config = original.config_whitelisted.dup
      end

      def replica?
        raise NotImplementedError
      end

      def migrations_paths
        raise NotImplementedError
      end

      def checkout_timeout
        config.fetch("checkout_timeout", 5).to_f
      end

      def idle_timeout
        idle_timeout = config.fetch("idle_timeout", 300).to_f
        idle_timeout if idle_timeout > 0
      end

      def pool
        config.fetch("pool", 5).to_i
      end

      def reaping_frequency
        config.fetch("reaping_frequency", 60).to_f
      end

      def database
        config["database"]
      end

      def url_config?
        false
      end

      def config_whitelisted
        config
      end

      def to_legacy_hash
        { env_name => config }
      end

      def for_current_env?
        env_name == ActiveRecord::ConnectionHandling::DEFAULT_ENV.call
      end
    end
  end
end
