ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # No database in this app (POROs only): skip Active Record fixtures/schema
    # maintenance and transactional wrapping so the suite runs with Postgres stopped.
    # Parallel workers fork and re-check the (nonexistent) schema per worker, which
    # hangs with no database, so tests run in a single process.
    self.use_transactional_tests = false

    # Add more helper methods to be used by all tests here...
  end
end
