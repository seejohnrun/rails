# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"
require "models/book"
require "models/post"
require "models/author"
require "models/event"

module ActiveRecord
  class AdapterPreventWritesTest < ActiveRecord::TestCase
    def setup
      @connection = ActiveRecord::Base.connection
    end

    def test_preventing_writes_predicate
      assert_not_predicate @connection, :preventing_writes?

      ActiveRecord::Base.while_preventing_writes do
        assert_predicate @connection, :preventing_writes?
      end

      assert_not_predicate @connection, :preventing_writes?
    end

    def test_errors_when_an_insert_query_is_called_while_preventing_writes
      assert_no_queries do
        assert_raises(ActiveRecord::ReadOnlyError) do
          ActiveRecord::Base.while_preventing_writes do
            @connection.transaction do
              @connection.insert("INSERT INTO subscribers(nick) VALUES ('138853948594')", nil, false)
            end
          end
        end
      end
    end

    def test_errors_when_an_update_query_is_called_while_preventing_writes
      @connection.insert("INSERT INTO subscribers(nick) VALUES ('138853948594')")

      assert_no_queries do
        assert_raises(ActiveRecord::ReadOnlyError) do
          ActiveRecord::Base.while_preventing_writes do
            @connection.transaction do
              @connection.update("UPDATE subscribers SET nick = '9989' WHERE nick = '138853948594'")
            end
          end
        end
      end
    end

    def test_errors_when_a_delete_query_is_called_while_preventing_writes
      @connection.insert("INSERT INTO subscribers(nick) VALUES ('138853948594')")

      assert_no_queries do
        assert_raises(ActiveRecord::ReadOnlyError) do
          ActiveRecord::Base.while_preventing_writes do
            @connection.transaction do
              @connection.delete("DELETE FROM subscribers WHERE nick = '138853948594'")
            end
          end
        end
      end
    end

    def test_doesnt_error_when_a_select_query_is_called_while_preventing_writes
      @connection.insert("INSERT INTO subscribers(nick) VALUES ('138853948594')")

      ActiveRecord::Base.while_preventing_writes do
        result = @connection.select_all("SELECT subscribers.* FROM subscribers WHERE nick = '138853948594'")
        assert_equal 1, result.length
      end
    end

    if ActiveRecord::Base.connection.supports_common_table_expressions?
      def test_doesnt_error_when_a_read_query_with_a_cte_is_called_while_preventing_writes
        @connection.insert("INSERT INTO subscribers(nick) VALUES ('138853948594')")

        ActiveRecord::Base.while_preventing_writes do
          result = @connection.select_all(<<~SQL)
            WITH matching_subscribers AS (SELECT subscribers.* FROM subscribers WHERE nick = '138853948594')
            SELECT * FROM matching_subscribers
          SQL
          assert_equal 1, result.length
        end
      end
    end
  end

  class AdapterPreventWritesLegacyTest < ActiveRecord::TestCase
    def setup
      @old_value = ActiveRecord::Base.legacy_connection_handling
      ActiveRecord::Base.legacy_connection_handling = true

      @connection = ActiveRecord::Base.connection
      @connection_handler = ActiveRecord::Base.connection_handler
    end

    def teardown
      clean_up_legacy_connection_handlers
      ActiveRecord::Base.legacy_connection_handling = @old_value
    end

    def test_preventing_writes_predicate_legacy
      assert_not_predicate @connection, :preventing_writes?

      assert_deprecated do
        @connection_handler.while_preventing_writes do
          assert_predicate @connection, :preventing_writes?
        end
      end

      assert_not_predicate @connection, :preventing_writes?
    end

    def test_errors_when_an_insert_query_is_called_while_preventing_writes
      assert_no_queries do
        assert_raises(ActiveRecord::ReadOnlyError) do
          assert_deprecated do
            @connection_handler.while_preventing_writes do
              @connection.transaction do
                @connection.insert("INSERT INTO subscribers(nick) VALUES ('138853948594')", nil, false)
              end
            end
          end
        end
      end
    end

    def test_errors_when_an_update_query_is_called_while_preventing_writes
      @connection.insert("INSERT INTO subscribers(nick) VALUES ('138853948594')")

      assert_no_queries do
        assert_raises(ActiveRecord::ReadOnlyError) do
          assert_deprecated do
            @connection_handler.while_preventing_writes do
              @connection.transaction do
                @connection.update("UPDATE subscribers SET nick = '9989' WHERE nick = '138853948594'")
              end
            end
          end
        end
      end
    end

    def test_errors_when_a_delete_query_is_called_while_preventing_writes
      @connection.insert("INSERT INTO subscribers(nick) VALUES ('138853948594')")

      assert_no_queries do
        assert_raises(ActiveRecord::ReadOnlyError) do
          assert_deprecated do
            @connection_handler.while_preventing_writes do
              @connection.transaction do
                @connection.delete("DELETE FROM subscribers WHERE nick = '138853948594'")
              end
            end
          end
        end
      end
    end

    def test_doesnt_error_when_a_select_query_is_called_while_preventing_writes
      @connection.insert("INSERT INTO subscribers(nick) VALUES ('138853948594')")

      assert_deprecated do
        @connection_handler.while_preventing_writes do
          result = @connection.select_all("SELECT subscribers.* FROM subscribers WHERE nick = '138853948594'")
          assert_equal 1, result.length
        end
      end
    end

    if ActiveRecord::Base.connection.supports_common_table_expressions?
      def test_doesnt_error_when_a_read_query_with_a_cte_is_called_while_preventing_writes
        @connection.insert("INSERT INTO subscribers(nick) VALUES ('138853948594')")

        assert_deprecated do
          @connection_handler.while_preventing_writes do
            result = @connection.select_all(<<~SQL)
            WITH matching_subscribers AS (SELECT subscribers.* FROM subscribers WHERE nick = '138853948594')
            SELECT * FROM matching_subscribers
            SQL
            assert_equal 1, result.length
          end
        end
      end
    end
  end
end
