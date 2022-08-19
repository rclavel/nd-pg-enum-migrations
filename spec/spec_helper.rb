# frozen_string_literal: true

require 'nd/pg/enum/migrations'
require 'database_cleaner/active_record'

db_config = YAML.load_file('config/database.yml')
ActiveRecord::Base.establish_connection(db_config['production'])

ActiveRecord::Schema.define do
  self.verbose = false
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.filter_run_when_matching :focus

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
