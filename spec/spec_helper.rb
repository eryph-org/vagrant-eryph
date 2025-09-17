require 'rspec'

# Load our Vagrant simulation before any plugin code
require_relative 'support/vagrant_simulator'

# Load cleanup helper for E2E tests
require_relative 'support/cleanup_helper'

# Configure RSpec
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.warnings = true
  
  if config.files_to_run.one?
    config.default_formatter = "doc"
  end

  config.order = :random
  Kernel.srand config.seed
  
  # Include test helpers
  config.include VagrantSimulator::TestHelpers

  # Final cleanup for E2E tests - only run when E2E tests are executed
  config.after(:suite) do
    if ENV['VAGRANT_ERYPH_E2E'] == 'true'
      CleanupHelper.final_cleanup
    end
  end
end