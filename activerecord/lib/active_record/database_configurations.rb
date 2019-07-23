# frozen_string_literal: true

require "active_record/database_configurations/database_config"
require "active_record/database_configurations/hash_config"
require "active_record/database_configurations/url_config"

module ActiveRecord
  # ActiveRecord::DatabaseConfigurations returns an array of DatabaseConfig
  # objects (either a HashConfig or UrlConfig) that are constructed from the
  # application's database configuration hash or URL string.
  class DatabaseConfigurations
    attr_reader :configurations
    delegate :any?, to: :configurations

    PRIMARY_SPEC_NAME = "primary".freeze

    def initialize(configurations = {})
      @configurations = build_configs(configurations)
    end

    # Collects the configs for the environment and optionally the specification
    # name passed in. To include replica configurations pass <tt>include_replicas: true</tt>.
    #
    # If a spec name is provided a single DatabaseConfig object will be
    # returned, otherwise an array of DatabaseConfig objects will be
    # returned that corresponds with the environment and type requested.
    #
    # ==== Options
    #
    # * <tt>env_name:</tt> The environment name. Defaults to +nil+ which will collect
    #   configs for all environments.
    # * <tt>spec_name:</tt> The specification name (i.e. primary, animals, etc.). Defaults
    #   to +nil+.
    # * <tt>include_replicas:</tt> Determines whether to include replicas in
    #   the returned list. Most of the time we're only iterating over the write
    #   connection (i.e. migrations don't need to run for the write and read connection).
    #   Defaults to +false+.
    def configs_for(env_name: nil, spec_name: nil, include_replicas: false)
      configs = env_with_configs(env_name)

      unless include_replicas
        configs = configs.select do |db_config|
          !db_config.replica?
        end
      end

      if spec_name
        configs.find do |db_config|
          db_config.spec_name == spec_name
        end
      else
        configs
      end
    end

    # Returns the config hash that corresponds with the environment
    #
    # If the application has multiple databases +default_hash+ will
    # return the first config hash for the environment.
    #
    #   { database: "my_db", adapter: "mysql2" }
    def default_hash(env = ActiveRecord::ConnectionHandling::DEFAULT_ENV.call.to_s)
      default = find_db_config(env)
      default.config if default
    end
    alias :[] :default_hash

    # Returns a single DatabaseConfig object based on the requested environment.
    #
    # If the application has multiple databases +find_db_config+ will return
    # the first DatabaseConfig for the environment.
    def find_db_config(env)
      configurations.find do |db_config|
        db_config.env_name == env.to_s ||
          (db_config.for_current_env? && db_config.spec_name == env.to_s)
      end
    end

    # Returns the DatabaseConfigurations object as a Hash.
    def to_h
      configs = configurations.reverse.inject({}) do |memo, db_config|
        memo.merge(db_config.to_legacy_hash)
      end

      Hash[configs.to_a.reverse]
    end

    # Checks if the application's configurations are empty.
    #
    # Aliased to blank?
    def empty?
      configurations.empty?
    end
    alias :blank? :empty?

    private
      def env_with_configs(env = nil)
        if env
          configurations.select { |db_config| db_config.env_name == env }
        else
          configurations
        end
      end

      def build_configs(configs)
        return configs.configurations if configs.is_a?(DatabaseConfigurations)
        return configs if configs.is_a?(Array)

        configs.each_pair.map do |env_name, config|
          walk_configs(env_name.to_s, config)
        end.flatten.compact
      end

      # Walk through the configuration in the case that it is nested, only
      # one level deep
      def walk_configs(env_name, config)
        if config["url"] || config["database"] || config["adapter"]
          return build_db_configuration(env_name, PRIMARY_SPEC_NAME, config)
        end

        config.map do |spec_name, spec_config|
          build_db_configuration(env_name, spec_name, spec_config)
        end
      end

      # Given a String or Hash, process the configuration and return a proper
      # configuration object
      def build_db_configuration(env_name, spec_name, config)
        env_key = "#{spec_name.upcase}_DATABASE_URL"
        if url = ENV[env_key]
          config = url
        end

        if url = ENV["DATABASE_URL"]
          config = url
        end

        case config
        when String
          build_db_config_from_string(env_name, spec_name, config)
        when Hash
          build_db_config_from_hash(env_name, spec_name, config.stringify_keys)
        end
      end

      def build_db_config_from_string(env_name, spec_name, config)
        url = config
        uri = URI.parse(url)
        if uri.try(:scheme)
          ActiveRecord::DatabaseConfigurations::UrlConfig.new(env_name, spec_name, url)
        end
      rescue URI::InvalidURIError
        ActiveRecord::DatabaseConfigurations::HashConfig.new(env_name, spec_name, config)
      end

      def build_db_config_from_hash(env_name, spec_name, config)
        if config.has_key?("url")
          url = config["url"]
          config_without_url = config.dup
          config_without_url.delete "url"

          ActiveRecord::DatabaseConfigurations::UrlConfig.new(env_name, spec_name, url, config_without_url)
        elsif config["database"] || config["adapter"]
          ActiveRecord::DatabaseConfigurations::HashConfig.new(env_name, spec_name, config)
        end
      end

      def method_missing(method, *args, &blk)
        case method
        when :each, :first
          throw_getter_deprecation(method)
          configurations.send(method, *args, &blk)
        when :fetch
          throw_getter_deprecation(method)
          configs_for(env_name: args.first)
        when :values
          throw_getter_deprecation(method)
          configurations.map(&:config)
        when :[]=
          throw_setter_deprecation(method)

          env_name = args[0]
          config = args[1]

          remaining_configs = configurations.reject { |db_config| db_config.env_name == env_name }
          new_config = build_configs(env_name => config)
          new_configs = remaining_configs + new_config

          ActiveRecord::Base.configurations = new_configs
        else
          raise NotImplementedError, "`ActiveRecord::Base.configurations` in Rails 6 now returns an object instead of a hash. The `#{method}` method is not supported. Please use `configs_for` or consult the documentation for supported methods."
        end
      end

      def throw_setter_deprecation(method)
        ActiveSupport::Deprecation.warn("Setting `ActiveRecord::Base.configurations` with `#{method}` is deprecated. Use `ActiveRecord::Base.configurations=` directly to set the configurations instead.")
      end

      def throw_getter_deprecation(method)
        ActiveSupport::Deprecation.warn("`ActiveRecord::Base.configurations` no longer returns a hash. Methods that act on the hash like `#{method}` are deprecated and will be removed in Rails 6.1. Use the `configs_for` method to collect and iterate over the database configurations.")
      end
  end
end
