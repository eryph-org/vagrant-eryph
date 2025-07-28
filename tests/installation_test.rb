require_relative 'support/test_helper'
require 'fileutils'

class InstallationTest
  include TestHelper
  
  def run_all
    puts "📦 Testing plugin installation process..."
    
    tests = [
      :test_gem_build_process,
      :test_vagrant_plugin_install,
      :test_plugin_listing,
      :test_plugin_functionality,
      :test_plugin_uninstall
    ]
    
    results = tests.map { |test| run_test_method(test.to_s.gsub('test_', ''), method(test)) }
    
    if results.all?
      puts "✅ All installation tests passed!"
    else
      puts "❌ Some installation tests failed"
      false
    end
  end
  
  private
  
  def test_gem_build_process
    puts "    Building gem package..."
    
    # Clean up any existing gem files
    Dir.glob('vagrant-eryph-*.gem').each { |f| File.delete(f) }
    
    # Build the gem
    result = capture_output('gem build vagrant-eryph.gemspec')
    assert(result[:success], "Gem build failed: #{result[:output]}")
    
    # Check if gem file was created
    gem_files = Dir.glob('vagrant-eryph-*.gem')
    assert(!gem_files.empty?, "No gem file was created")
    
    @gem_file = gem_files.first
    puts "      Created: #{@gem_file}"
    
    true
  end
  
  def test_vagrant_plugin_install
    return skip_test("Gem build failed") unless @gem_file
    
    puts "    Installing plugin in Vagrant..."
    
    # Uninstall plugin if already installed (from previous tests)
    system('vagrant plugin uninstall vagrant-eryph > nul 2>&1')
    
    # Install the plugin
    result = capture_output("vagrant plugin install #{@gem_file}")
    assert(result[:success], "Plugin installation failed: #{result[:output]}")
    
    puts "      Plugin installed successfully"
    true
  end
  
  def test_plugin_listing
    puts "    Verifying plugin is listed..."
    
    result = capture_output('vagrant plugin list')
    assert(result[:success], "Failed to list plugins")
    assert(result[:output].include?('vagrant-eryph'), "Plugin not found in plugin list")
    
    # Extract version from listing
    if result[:output] =~ /vagrant-eryph \(([^)]+)\)/
      version = $1
      puts "      Found vagrant-eryph version #{version}"
    end
    
    true
  end
  
  def test_plugin_functionality
    puts "    Testing basic plugin functionality..."
    
    with_temp_dir do |test_dir|
      puts "        Temp directory created: #{test_dir}"
      Dir.chdir(test_dir) do
        puts "        Changed to directory: #{Dir.pwd}"
        
        # Create a basic Vagrantfile
        vagrantfile_content = <<~RUBY
          Vagrant.configure("2") do |config|
            config.vm.provider :eryph do |eryph|
              eryph.project = "test-project"
              eryph.parent_gene = "dbosoft/ubuntu-22.04/latest"
            end
          end
        RUBY
        
        File.write('Vagrantfile', vagrantfile_content)
        puts "        Vagrantfile written, exists: #{File.exist?('Vagrantfile')}"
        
        # Test vagrant status (should recognize the provider)
        # Add debug info about current directory and Vagrantfile
        puts "        Current directory: #{Dir.pwd}"
        puts "        Vagrantfile exists: #{File.exist?('Vagrantfile')}"
        
        result = capture_output('vagrant status --machine-readable')
        assert(result[:success], "Vagrant status failed: #{result[:output]}")
        
        # Check if provider is recognized
        assert(result[:output].include?('eryph') || result[:output].include?('provider-name'), 
               "Eryph provider not recognized")
        
        puts "      Provider recognized by Vagrant"
      end
    end
    
    true
  end
  
  def test_plugin_uninstall
    puts "    Testing plugin uninstall..."
    
    result = capture_output('vagrant plugin uninstall vagrant-eryph')
    assert(result[:success], "Plugin uninstall failed: #{result[:output]}")
    
    # Verify plugin is no longer listed
    list_result = capture_output('vagrant plugin list')
    assert(list_result[:success], "Failed to list plugins after uninstall")
    assert(!list_result[:output].include?('vagrant-eryph'), "Plugin still listed after uninstall")
    
    puts "      Plugin uninstalled successfully"
    true
  end
  
  def cleanup
    # Clean up gem files
    Dir.glob('vagrant-eryph-*.gem').each { |f| File.delete(f) }
    
    # Ensure plugin is uninstalled
    system('vagrant plugin uninstall vagrant-eryph > nul 2>&1')
  end
end