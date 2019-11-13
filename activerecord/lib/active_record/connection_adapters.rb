# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :AbstractAdapter
    end

    autoload :Column
    autoload :PoolConfig
    autoload :PoolManager
    autoload :Resolver

    autoload_at "active_record/connection_adapters/abstract/schema_definitions" do
      autoload :IndexDefinition
      autoload :ColumnDefinition
      autoload :ChangeColumnDefinition
      autoload :ForeignKeyDefinition
      autoload :TableDefinition
      autoload :Table
      autoload :AlterTable
      autoload :ReferenceDefinition
    end

    autoload_at "active_record/connection_adapters/abstract/connection_pool" do
      autoload :ConnectionHandler
    end

    autoload_under "abstract" do
      autoload :SchemaStatements
      autoload :DatabaseStatements
      autoload :DatabaseLimits
      autoload :Quoting
      autoload :ConnectionPool
      autoload :QueryCache
      autoload :Savepoints
    end

    autoload_at "active_record/connection_adapters/abstract/transaction" do
      autoload :TransactionManager
      autoload :NullTransaction
      autoload :RealTransaction
      autoload :SavepointTransaction
      autoload :TransactionState
    end

    def self.adapter_method_for(adapter) # :nodoc:
      "#{adapter}_connection"
    end

    def self.load_adapter(adapter) # :nodoc:
      raise(AdapterNotSpecified, "database configuration does not specify adapter") unless adapter

      # Require the adapter itself and give useful feedback about
      #   1. Missing adapter gems and
      #   2. Adapter gems' missing dependencies.
      path_to_adapter = "active_record/connection_adapters/#{adapter}_adapter"
      begin
        require path_to_adapter
      rescue LoadError => e
        # We couldn't require the adapter itself. Raise an exception that
        # points out config typos and missing gems.
        if e.path == path_to_adapter
          # We can assume that a non-builtin adapter was specified, so it's
          # either misspelled or missing from Gemfile.
          raise LoadError, "Could not load the '#{adapter}' Active Record adapter. Ensure that the adapter is spelled correctly in config/database.yml and that you've added the necessary adapter gem to your Gemfile.", e.backtrace

          # Bubbled up from the adapter require. Prefix the exception message
          # with some guidance about how to address it and reraise.
        else
          raise LoadError, "Error loading the '#{adapter}' Active Record adapter. Missing a gem it depends on? #{e.message}", e.backtrace
        end
      end

      unless ActiveRecord::Base.respond_to?(adapter_method_for(adapter))
        raise AdapterNotFound, "database configuration specifies nonexistent #{adapter} adapter"
      end
    end
  end
end
