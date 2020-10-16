# frozen_string_literal: true

require "cases/helper"
require "models/person"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionSwappingNestedTest < ActiveRecord::TestCase
      self.use_transactional_tests = false

      fixtures :people

      def teardown
        clean_up_connection_handler
      end

      class PrimaryBase < ActiveRecord::Base
        self.abstract_class = true
      end

      class PrimaryModel < PrimaryBase
      end

      class SecondaryBase < ActiveRecord::Base
        self.abstract_class = true
      end

      class SecondaryModel < SecondaryBase
      end

      unless in_memory_db?
        def test_roles_can_be_swapped_granularly
          previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"

          config = {
            "default_env" => {
              "primary"  => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" },
              "primary_replica"  => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3", "replica" => true },
              "secondary" => { "adapter" => "sqlite3", "database" => "test/db/secondary.sqlite3" },
              "secondary_replica" => { "adapter" => "sqlite3", "database" => "test/db/secondary_replica.sqlite3", "replica" => true }
            }
          }

          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          PrimaryBase.connects_to database: { writing: :primary, reading: :primary_replica }
          SecondaryBase.connects_to database: { writing: :secondary, reading: :secondary_replica }

          # Switch everything to writing
          ActiveRecord::Base.connected_to(role: :writing) do
            assert_equal "primary", PrimaryBase.connection_pool.db_config.name
            assert_equal "secondary", SecondaryBase.connection_pool.db_config.name

            # Switch only primary to reading
            PrimaryBase.connected_to(role: :reading) do
              assert_equal "primary_replica", PrimaryBase.connection_pool.db_config.name
              assert_equal "secondary", SecondaryBase.connection_pool.db_config.name

              # Switch global to reading
              ActiveRecord::Base.connected_to(role: :reading) do
                assert_equal "primary_replica", PrimaryBase.connection_pool.db_config.name
                assert_equal "secondary_replica", SecondaryBase.connection_pool.db_config.name

                # Switch only secondary to writing
                SecondaryBase.connected_to(role: :writing) do
                  assert_equal "primary_replica", PrimaryBase.connection_pool.db_config.name
                  assert_equal "secondary", SecondaryBase.connection_pool.db_config.name
                end

                # Ensure restored to global reading
                assert_equal "primary_replica", PrimaryBase.connection_pool.db_config.name
                assert_equal "secondary_replica", SecondaryBase.connection_pool.db_config.name
              end

              # Switch everything to writing
              ActiveRecord::Base.connected_to(role: :writing) do
                assert_equal "primary", PrimaryBase.connection_pool.db_config.name
                assert_equal "secondary", SecondaryBase.connection_pool.db_config.name
              end

              # Ensure restored to primary reading
              assert_equal "primary_replica", PrimaryBase.connection_pool.db_config.name
              assert_equal "secondary", SecondaryBase.connection_pool.db_config.name
            end

            # Ensure restored to global writing
            assert_equal "primary", PrimaryBase.connection_pool.db_config.name
            assert_equal "secondary", SecondaryBase.connection_pool.db_config.name
          end
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
          ENV["RAILS_ENV"] = previous_env
        end

        def test_shards_can_be_swapped_granularly
          previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"

          config = {
            "default_env" => {
              "primary"  => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" },
              "primary_replica"  => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3", "replica" => true },
              "primary_shard_one" => { "adapter" => "sqlite3", "database" => "test/db/primary_shard_one.sqlite3" },
              "primary_shard_one_replica" => { "adapter" => "sqlite3", "database" => "test/db/primary_shard_one.sqlite3", "replica" => true },
              "primary_shard_two" => { "adapter" => "sqlite3", "database" => "test/db/primary_shard_two.sqlite3" },
              "primary_shard_two_replica" => { "adapter" => "sqlite3", "database" => "test/db/primary_shard_two.sqlite3", "replica" => true },
              "secondary"  => { "adapter" => "sqlite3", "database" => "test/db/secondary.sqlite3" },
              "secondary_replica"  => { "adapter" => "sqlite3", "database" => "test/db/secondary.sqlite3", "replica" => true },
              "secondary_shard_one" => { "adapter" => "sqlite3", "database" => "test/db/secondary_shard_one.sqlite3" },
              "secondary_shard_one_replica" => { "adapter" => "sqlite3", "database" => "test/db/secondary_shard_one.sqlite3", "replica" => true },
              "secondary_shard_two" => { "adapter" => "sqlite3", "database" => "test/db/secondary_shard_two.sqlite3" },
              "secondary_shard_two_replica" => { "adapter" => "sqlite3", "database" => "test/db/secondary_shard_two.sqlite3", "replica" => true }
            }
          }

          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          PrimaryBase.connects_to(shards: {
            default: { writing: :primary, reading: :primary_replica },
            shard_one: { writing: :primary_shard_one, reading: :primary_shard_one_replica }
          })

          SecondaryBase.connects_to(shards: {
            default: { writing: :secondary, reading: :secondary_replica },
            shard_one: { writing: :secondary_shard_one, reading: :secondary_shard_one_replica },
            shard_two: { writing: :secondary_shard_two, reading: :secondary_shard_two_replica }
          })

          global_role = :writing

          # Switch everything to default
          ActiveRecord::Base.connected_to(role: global_role, shard: :default) do
            assert_equal "primary", PrimaryBase.connection_pool.db_config.name
            assert_equal "secondary", SecondaryBase.connection_pool.db_config.name

            # Switch only primary to shard_one
            PrimaryBase.connected_to(role: global_role, shard: :shard_one) do
              assert_equal "primary_shard_one", PrimaryBase.connection_pool.db_config.name
              assert_equal "secondary", SecondaryBase.connection_pool.db_config.name

              # Switch global to shard_one
              ActiveRecord::Base.connected_to(role: global_role, shard: :shard_one) do
                assert_equal "primary_shard_one", PrimaryBase.connection_pool.db_config.name
                assert_equal "secondary_shard_one", SecondaryBase.connection_pool.db_config.name

                # Switch only secondary to shard_two
                SecondaryBase.connected_to(role: global_role, shard: :shard_two) do
                  assert_equal "primary_shard_one", PrimaryBase.connection_pool.db_config.name
                  assert_equal "secondary_shard_two", SecondaryBase.connection_pool.db_config.name
                end

                # Ensure restored to global shard_one
                assert_equal "primary_shard_one", PrimaryBase.connection_pool.db_config.name
                assert_equal "secondary_shard_one", SecondaryBase.connection_pool.db_config.name

                # When shard not specified, leave things as-is
                ActiveRecord::Base.connected_to(role: global_role) do
                  assert_equal "primary_shard_one", PrimaryBase.connection_pool.db_config.name
                  assert_equal "secondary_shard_one", SecondaryBase.connection_pool.db_config.name
                end
              end

              # Switch everything to default
              ActiveRecord::Base.connected_to(role: global_role, shard: :default) do
                assert_equal "primary", PrimaryBase.connection_pool.db_config.name
                assert_equal "secondary", SecondaryBase.connection_pool.db_config.name
              end

              # Ensure restored to primary shard_one
              assert_equal "primary_shard_one", PrimaryBase.connection_pool.db_config.name
              assert_equal "secondary", SecondaryBase.connection_pool.db_config.name
            end

            # Ensure restored to global default
            assert_equal "primary", PrimaryBase.connection_pool.db_config.name
            assert_equal "secondary", SecondaryBase.connection_pool.db_config.name
          end
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
          ENV["RAILS_ENV"] = previous_env
        end

        def test_roles_and_shards_can_be_swapped_granularly
          previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"

          config = {
            "default_env" => {
              "primary"  => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" },
              "primary_replica"  => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3", "replica" => true },
              "primary_shard_one" => { "adapter" => "sqlite3", "database" => "test/db/primary_shard_one.sqlite3" },
              "primary_shard_one_replica" => { "adapter" => "sqlite3", "database" => "test/db/primary_shard_one.sqlite3", "replica" => true },
              "primary_shard_two" => { "adapter" => "sqlite3", "database" => "test/db/primary_shard_two.sqlite3" },
              "primary_shard_two_replica" => { "adapter" => "sqlite3", "database" => "test/db/primary_shard_two.sqlite3", "replica" => true },
              "secondary"  => { "adapter" => "sqlite3", "database" => "test/db/secondary.sqlite3" },
              "secondary_replica"  => { "adapter" => "sqlite3", "database" => "test/db/secondary.sqlite3", "replica" => true },
              "secondary_shard_one" => { "adapter" => "sqlite3", "database" => "test/db/secondary_shard_one.sqlite3" },
              "secondary_shard_one_replica" => { "adapter" => "sqlite3", "database" => "test/db/secondary_shard_one.sqlite3", "replica" => true },
              "secondary_shard_two" => { "adapter" => "sqlite3", "database" => "test/db/secondary_shard_two.sqlite3" },
              "secondary_shard_two_replica" => { "adapter" => "sqlite3", "database" => "test/db/secondary_shard_two.sqlite3", "replica" => true }
            }
          }

          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          PrimaryBase.connects_to(shards: {
            default: { writing: :primary, reading: :primary_replica },
            shard_one: { writing: :primary_shard_one, reading: :primary_shard_one_replica }
          })

          SecondaryBase.connects_to(shards: {
            default: { writing: :secondary, reading: :secondary_replica },
            shard_one: { writing: :secondary_shard_one, reading: :secondary_shard_one_replica },
            shard_two: { writing: :secondary_shard_two, reading: :secondary_shard_two_replica }
          })

          # Switch everything to writing, default shard
          ActiveRecord::Base.connected_to(role: :writing, shard: :default) do
            assert_equal "primary", PrimaryBase.connection_pool.db_config.name
            assert_equal "secondary", SecondaryBase.connection_pool.db_config.name

            # Switch only primary to reading, shard_one
            PrimaryBase.connected_to(role: :reading, shard: :shard_one) do
              assert_equal "primary_shard_one_replica", PrimaryBase.connection_pool.db_config.name
              assert_equal "secondary", SecondaryBase.connection_pool.db_config.name

              # Switch global to reading, shard_one
              ActiveRecord::Base.connected_to(role: :reading, shard: :shard_one) do
                assert_equal "primary_shard_one_replica", PrimaryBase.connection_pool.db_config.name
                assert_equal "secondary_shard_one_replica", SecondaryBase.connection_pool.db_config.name

                # Switch only secondary to writing shard_two
                SecondaryBase.connected_to(role: :writing, shard: :shard_two) do
                  assert_equal "primary_shard_one_replica", PrimaryBase.connection_pool.db_config.name
                  assert_equal "secondary_shard_two", SecondaryBase.connection_pool.db_config.name
                end

                # Ensure restored to global reading, shard_one
                assert_equal "primary_shard_one_replica", PrimaryBase.connection_pool.db_config.name
                assert_equal "secondary_shard_one_replica", SecondaryBase.connection_pool.db_config.name

                # When shard not specified, leave shard alone
                ActiveRecord::Base.connected_to(role: :writing) do
                  assert_equal "primary_shard_one", PrimaryBase.connection_pool.db_config.name
                  assert_equal "secondary_shard_one", SecondaryBase.connection_pool.db_config.name
                end
              end

              # Switch everything to writing, shard default
              ActiveRecord::Base.connected_to(role: :writing, shard: :default) do
                assert_equal "primary", PrimaryBase.connection_pool.db_config.name
                assert_equal "secondary", SecondaryBase.connection_pool.db_config.name
              end

              # Ensure restored to primary reading shard_one, secondary writing default
              assert_equal "primary_shard_one_replica", PrimaryBase.connection_pool.db_config.name
              assert_equal "secondary", SecondaryBase.connection_pool.db_config.name
            end

            # Ensure restored to global writing, default shard
            assert_equal "primary", PrimaryBase.connection_pool.db_config.name
            assert_equal "secondary", SecondaryBase.connection_pool.db_config.name
          end
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
          ENV["RAILS_ENV"] = previous_env
        end
      end
    end
  end
end
