require 'rspec/core/rake_task'

# Unit tests - fast, use simulation
RSpec::Core::RakeTask.new(:unit) do |t|
  t.pattern = 'spec/unit/**/*_spec.rb'
  t.rspec_opts = '--format documentation --color'
end

# E2E tests - slow, require real Vagrant + Eryph
RSpec::Core::RakeTask.new(:e2e) do |t|
  t.pattern = 'spec/e2e/**/*_spec.rb'
  t.rspec_opts = '--format documentation --color'
end

# All tests
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/**/*_spec.rb'
  t.rspec_opts = '--format documentation --color'
end

# Unit tests with JUnit output for CI
RSpec::Core::RakeTask.new('unit:ci') do |t|
  t.pattern = 'spec/unit/**/*_spec.rb'
  t.rspec_opts = '--format progress --format RspecJunitFormatter --out test-results-unit.xml'
end

# E2E tests with JUnit output for CI
RSpec::Core::RakeTask.new('e2e:ci') do |t|
  t.pattern = 'spec/e2e/**/*_spec.rb'
  t.rspec_opts = '--format progress --format RspecJunitFormatter --out test-results-e2e.xml'
end

# Default task
task default: :unit

# Build gem
task :build do
  # Clean up any existing gem files
  Dir.glob('vagrant-eryph-*.gem').each { |f| File.delete(f) }
  
  if Gem.win_platform?
    system('cmd /c "gem build vagrant-eryph.gemspec"') or exit(1)
  else
    system('gem build vagrant-eryph.gemspec') or exit(1)
  end
  
  gem_files = Dir.glob('vagrant-eryph-*.gem')
  raise "No gem file created after build" if gem_files.empty?
  puts "Successfully built: #{gem_files.first}"
end

# Install gem locally for testing
task install: :build do
  # Find the gem file
  gem_file = Dir['vagrant-eryph-*.gem'].max_by { |f| File.mtime(f) }
  raise "No gem file found" unless gem_file
  
  system("vagrant plugin install #{gem_file}") or exit(1)
  puts "Plugin installed successfully"
end

# Uninstall gem
task :uninstall do
  system('vagrant plugin uninstall vagrant-eryph')
  puts "Plugin uninstalled (if it was installed)"
end

# Reinstall gem (for development)
task reinstall: [:uninstall, :install]

desc "Show test information"
task :test_info do
  puts <<~INFO
    Test Strategy:
    
    Unit Tests (rake unit):
    - Fast simulation-based tests
    - Test individual components with realistic Vagrant mock
    - Focus on logic, configuration, state management
    - NO environment dependencies
    
    E2E Tests (rake e2e): 
    - Full Vagrant command execution
    - Real catlet deployment and lifecycle
    - Tests assume Vagrant + Eryph + plugin are ready
    - FAIL if dependencies missing (no environment checks)
    
    Commands:
    rake unit     - Run unit tests only
    rake e2e      - Run E2E tests only  
    rake spec     - Run all tests
    rake install  - Build and install plugin
    
    E2E Requirements (NO CHECKS - just assume ready):
    - Vagrant installed
    - Eryph running
    - Plugin installed (rake install)
    
    Test Principle: Tests assume environment is correct!
    Missing dependencies = natural test failure
  INFO
end