# frozen_string_literal: true

require "trevl"
require "webmock/rspec"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.order = :random

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    Trevl.reset!
    Trevl::DataSource.reset!
  end
end
