# README

Portfolio rebalance recommendation tool. Domain logic (`Stock`, `Holding`,
`TargetAllocation`, `Portfolio`, `RebalancePlan`) is plain Ruby objects, not
Active Record models — there is no database to set up or migrate.

## Running the app

    bin/rails server

Then open `/` for the rebalance form.

## Running the test suite

    bin/rails test

No database is required (Postgres does not need to be running): the `pg` gem
and `config/database.yml` stay in place for a future persistence layer, but
`config/environments/test.rb` disables Active Record's pending-schema check
(`config.active_record.maintain_test_schema = false`) and `test_helper.rb`
disables transactional fixtures (`self.use_transactional_tests = false`), so
booting the test environment never opens a database connection.

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
