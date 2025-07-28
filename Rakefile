require 'rspec/core/rake_task'

# Test hierarchy with proper ordering
desc "Run structure tests (basic file validation)"
RSpec::Core::RakeTask.new(:structure) do |t|
  t.pattern = 'spec/structure_spec.rb'
  t.rspec_opts = '--format documentation --color'
end

desc "Run unit tests (mocked components)"
RSpec::Core::RakeTask.new(:unit) do |t|
  t.pattern = 'spec/unit/**/*_spec.rb'
  t.rspec_opts = '--format documentation --color'
end

desc "Run installation tests (gem build and plugin install)"
RSpec::Core::RakeTask.new(:install) do |t|
  t.pattern = 'spec/installation_simple_spec.rb'
  t.rspec_opts = '--format documentation --color'
end

# Make install depend on build
task :install => :build

desc "Run integration tests (plugin functionality with Vagrant)"
RSpec::Core::RakeTask.new(:integration) do |t|
  t.pattern = 'spec/integration/**/*_spec.rb'
  t.rspec_opts = '--format documentation --color --tag ~slow'
end

desc "Run E2E tests (full catlet lifecycle with Eryph)"
RSpec::Core::RakeTask.new(:e2e) do |t|
  t.pattern = 'spec/e2e/**/*_spec.rb'
  t.rspec_opts = '--format documentation --color'
end

# Manual build task to avoid Git Bash path issues with bundler
desc "Build the gem package"
task :build do
  # Clean up any existing gem files
  Dir.glob('vagrant-eryph-*.gem').each { |f| File.delete(f) }
  
  # Build the gem using cmd on Windows to avoid Git Bash path issues
  if Gem.win_platform?
    success = system('cmd /c "gem build vagrant-eryph.gemspec"')
  else
    success = system('gem build vagrant-eryph.gemspec')
  end
  
  raise "Failed to build gem" unless success
  
  # Verify gem file exists
  gem_files = Dir.glob('vagrant-eryph-*.gem')
  raise "No gem file created after build" if gem_files.empty?
  
  puts "Successfully built: #{gem_files.first}"
end

# Composite tasks with proper dependencies
desc "Run basic tests (structure + unit)"
task basic: [:structure, :unit]

desc "Run development tests (basic + installation)"
task dev: [:structure, :unit, :install]

desc "Run full test suite in proper order"
task full: [:structure, :unit, :install, :integration, :e2e]

desc "Run full test suite with integration enabled"
task :full_with_integration do
  ENV['VAGRANT_ERYPH_INTEGRATION'] = 'true'
  Rake::Task[:full].invoke
end

# Default to basic tests for quick development feedback
task default: :basic

# Legacy support
task spec: :unit
task :legacy_test do
  ruby 'tests/test_runner.rb'
end

desc "Show test hierarchy and usage"
task :test_help do
  puts <<~HELP
    Test Hierarchy (run in order):
    
    1. rake structure     - Verify files exist, basic syntax
    2. rake unit         - Test individual components (mocked)
    3. rake install      - Build gem and install Vagrant plugin
    4. rake integration  - Test plugin with Vagrant (requires plugin installed)
    5. rake e2e          - Full catlet lifecycle with Eryph (requires Eryph running)
    
    Composite Tasks:
    rake basic          - structure + unit (fast development feedback)
    rake dev            - basic + install (for plugin development)
    rake full           - complete test suite in proper order
    
    Environment Variables:
    VAGRANT_ERYPH_INTEGRATION=true  - Enable integration/E2E tests
    VAGRANT_ERYPH_DEBUG=true        - Enable debug output
    VAGRANT_ERYPH_MOCK_CLIENT=true  - Force mock client for testing
  HELP
end