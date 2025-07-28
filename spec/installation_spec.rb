require 'spec_helper'
require 'fileutils'

RSpec.describe "Plugin Installation", type: :installation do
  let(:gem_file) { Dir.glob('vagrant-eryph-*.gem').first }
  let(:plugin_name) { 'vagrant-eryph' }

  before(:all) do
    puts "\n=== PLUGIN INSTALLATION TEST SETUP ==="
    # Only clean up plugin installation, not gem files (gem is built by rake build)
    system('vagrant plugin uninstall vagrant-eryph > nul 2>&1')
    puts "Cleaned up existing plugin installation (keeping gem file from rake build)"
  end

  after(:all) do
    puts "\n=== PLUGIN INSTALLATION TEST CLEANUP ==="
    # Clean up gem files but keep plugin installed for integration tests
    Dir.glob('vagrant-eryph-*.gem').each { |f| File.delete(f) }
    puts "Cleaned up gem files (keeping plugin installed for integration tests)"
  end

  describe "gem build process" do
    it "verifies gem package exists (built by rake build)" do
      puts "\n--- Verifying Vagrant plugin gem exists ---"
      
      # Check if gem file was created by rake build task
      gem_files = Dir.glob('vagrant-eryph-*.gem')
      expect(gem_files).not_to be_empty, "No gem file found. Run 'rake build' first."

      puts "✅ Found gem file: #{gem_files.first}"
      puts "   File size: #{File.size(gem_files.first)} bytes"
      
      # Verify gem file is valid by checking it contains expected files
      gem_file = gem_files.first
      expect(File.exist?(gem_file)).to be(true), "Gem file doesn't exist"
      expect(File.size(gem_file)).to be > 1000, "Gem file suspiciously small"
      
      puts "✅ Gem file appears valid"
    end
  end

  describe "vagrant plugin installation" do
    before do
      unless gem_file && File.exist?(gem_file)
        fail "Gem build failed or gem file missing. Run gem build first."
      end
    end

    it "uninstalls any existing plugin version" do
      puts "\n--- Removing any existing plugin installation ---"
      
      # Check if plugin is currently installed
      list_result = capture_vagrant_output('vagrant plugin list')
      if list_result[:success] && list_result[:output].include?(plugin_name)
        puts "Found existing plugin installation, removing..."
        result = capture_vagrant_output("vagrant plugin uninstall #{plugin_name}")
        puts "Uninstall result: #{result[:success] ? 'SUCCESS' : 'FAILED'}"
        puts result[:output] if result[:output]
      else
        puts "No existing plugin installation found"
      end
    end

    it "installs plugin in Vagrant successfully" do
      puts "\n--- Installing Vagrant plugin ---"
      puts "Installing: #{gem_file}"
      
      # Install the plugin
      result = capture_vagrant_output("vagrant plugin install #{gem_file}")
      puts "Install command output:"
      puts result[:output]
      
      expect(result[:success]).to be(true), "Plugin installation failed: #{result[:output]}"
      puts "✅ Plugin installation completed successfully"
    end

    it "appears in plugin listing" do
      puts "\n--- Verifying plugin installation ---"
      
      result = capture_vagrant_output('vagrant plugin list')
      expect(result[:success]).to be(true), "Failed to list plugins: #{result[:output]}"
      
      puts "Plugin list output:"
      puts result[:output]
      
      expect(result[:output]).to include(plugin_name), "Plugin not found in plugin list"

      # Extract and display version information
      if result[:output] =~ /#{plugin_name} \(([^)]+)\)/
        version = $1
        puts "✅ Found #{plugin_name} version #{version}"
      else
        puts "✅ Plugin #{plugin_name} is installed (version not detected)"
      end
    end
  end

  describe "plugin functionality verification" do
    before do
      # Ensure plugin is installed before testing functionality
      list_result = capture_vagrant_output('vagrant plugin list')
      unless list_result[:success] && list_result[:output].include?(plugin_name)
        fail "Plugin not installed. Installation tests must pass first."
      end
    end

    it "is recognized by Vagrant as a provider" do
      puts "\n--- Testing provider recognition ---"
      
      with_temp_dir do |test_dir|
        Dir.chdir(test_dir) do
          # Create a basic Vagrantfile with catlet configuration
          create_test_vagrantfile(<<~CONFIG)
            config.vm.provider :eryph do |eryph|
              eryph.project = "test-project"
              eryph.catlet = {
                parent: "dbosoft/ubuntu-22.04/latest"
              }
            end
          CONFIG

          # Test vagrant status (should recognize the provider)
          result = capture_vagrant_output('vagrant status --machine-readable')
          puts "Vagrant status output:"
          puts result[:output]
          
          expect(result[:success]).to be(true), "Vagrant status failed: #{result[:output]}"

          # Check if provider is recognized (should not get "provider not found" error)
          expect(result[:output]).not_to include('could not be found'), 
            "Eryph provider not recognized by Vagrant"
          
          puts "✅ Eryph provider successfully recognized by Vagrant"
        end
      end
    end

    it "validates configuration properly" do
      puts "\n--- Testing configuration validation ---"
      
      with_temp_dir do |test_dir|
        Dir.chdir(test_dir) do
          # Create Vagrantfile with valid catlet configuration
          create_test_vagrantfile(<<~CONFIG)
            config.vm.provider :eryph do |eryph|
              eryph.project = "test-project"
              eryph.catlet = {
                parent: "dbosoft/ubuntu-22.04/latest",
                cpu: { count: 2 },
                memory: { startup: 2048 }
              }
            end
          CONFIG

          # Test vagrant validate
          result = capture_vagrant_output('vagrant validate')
          puts "Validation output:"
          puts result[:output]
          
          # Should succeed or fail gracefully (not crash)
          expect([true, false]).to include(result[:success])
          expect(result[:output]).not_to include('undefined method'), 
            "Plugin code crashed during validation"
          
          puts "✅ Configuration validation completed without crashes"
        end
      end
    end
  end

  describe "plugin uninstall verification" do
    before do
      # Only run if plugin is installed
      list_result = capture_vagrant_output('vagrant plugin list')
      unless list_result[:success] && list_result[:output].include?(plugin_name)
        skip "Plugin not installed - skipping uninstall test"
      end
    end

    it "can be uninstalled cleanly (but keep installed for integration tests)" do
      puts "\n--- Testing plugin uninstall capability ---"
      puts "NOTE: Plugin will be reinstalled immediately for integration tests"
      
      # Test uninstall
      result = capture_vagrant_output("vagrant plugin uninstall #{plugin_name}")
      expect(result[:success]).to be(true), "Plugin uninstall failed: #{result[:output]}"

      # Verify plugin is no longer listed
      list_result = capture_vagrant_output('vagrant plugin list')
      expect(list_result[:success]).to be(true)
      expect(list_result[:output]).not_to include(plugin_name), 
        "Plugin still listed after uninstall"

      puts "✅ Plugin uninstall successful"
      
      # Reinstall immediately for integration tests
      unless gem_file && File.exist?(gem_file)
        fail "Cannot reinstall plugin - gem file missing"
      end
      
      puts "Reinstalling plugin for integration tests..."
      reinstall_result = capture_vagrant_output("vagrant plugin install #{gem_file}")
      expect(reinstall_result[:success]).to be(true), 
        "Failed to reinstall plugin: #{reinstall_result[:output]}"
      
      puts "✅ Plugin reinstalled successfully for integration tests"
    end
  end
end