# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class PoolManager # :nodoc:
      def initialize
        @name_to_role_mapping = Hash.new { |h, k| h[k] = {} }
      end

      def role_names
        @name_to_role_mapping.keys
      end

      def pool_configs
        @name_to_role_mapping.flat_map { |_role, shard_map| shard_map.values.compact }
      end

      def remove_pool_config(role, shard)
        @name_to_role_mapping[role].delete(shard)
      end

      def get_pool_config(role, shard)
        @name_to_role_mapping[role][shard]
      end

      def set_pool_config(role, shard, pool_config)
        @name_to_role_mapping[role][shard] = pool_config
      end
    end
  end
end
