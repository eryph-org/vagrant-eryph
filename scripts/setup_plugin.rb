#!/usr/bin/env ruby

require 'fileutils'

class VagrantPluginSetup
  def initialize
    @plugin_name = 'vagrant-eryph'
    @gem_pattern = "#{@plugin_name}-*.gem"
    @project_root = File.expand_path('..', __dir__)
  end
  
  def run
    puts "🔧 Setting up Vagrant Eryph Plugin for Testing"
    puts "=" * 60
    
    change_to_project_root
    cleanup_old_gems
    build_gem
    uninstall_existing_plugin
    install_plugin
    verify_installation
    
    puts "\n✅ Plugin setup completed successfully!"
    puts "\nNext steps:"
    puts "  - Run integration tests: ruby tests/test_runner.rb"
    puts "  - Set VAGRANT_ERYPH_INTEGRATION=true for full tests"
  end
  
  private
  
  def change_to_project_root
    puts "\n📁 Changing to project root: #{@project_root}"
    Dir.chdir(@project_root)
  end
  
  def cleanup_old_gems
    puts "\n🧹 Cleaning up old gem files..."
    Dir.glob(@gem_pattern).each do |gem_file|
      puts "  Removing: #{gem_file}"
      File.delete(gem_file)
    end
  end
  
  def build_gem
    puts "\n🔨 Building gem package..."
    
    output = `gem build vagrant-eryph.gemspec 2>&1`
    result = $?.success?
    
    unless result
      puts "❌ Gem build failed!"
      puts "Error output: #{output}"
      exit 1
    end
    
    @gem_file = Dir.glob(@gem_pattern).first
    unless @gem_file
      puts "❌ No gem file found after build!"
      puts "Build output: #{output}"
      exit 1
    end
    
    puts "  ✅ Built: #{@gem_file}"
  end
  
  def uninstall_existing_plugin
    puts "\n🗑️  Uninstalling existing plugin (if any)..."
    
    # Check if plugin is installed
    result = `vagrant plugin list 2>&1`
    if result.include?(@plugin_name)
      puts "  Found existing installation, uninstalling..."
      uninstall_result = system("vagrant plugin uninstall #{@plugin_name}")
      if uninstall_result
        puts "  ✅ Uninstalled existing plugin"
      else
        puts "  ⚠️  Uninstall command returned error, continuing anyway..."
      end
    else
      puts "  No existing installation found"
    end
    
    # Also clean up dependencies if needed (for fresh install)
    puts "  Checking for existing Eryph dependencies..."
    dependencies = ['eryph-compute', 'eryph-clientruntime']
    dependencies.each do |dep|
      if result.include?(dep)
        puts "  Uninstalling #{dep}..."
        system("vagrant plugin uninstall #{dep}")
      end
    end
  end
  
  def install_plugin
    puts "\n📦 Installing plugin..."
    
    # First install local dependencies from ruby-client
    install_local_dependencies
    
    result = system("vagrant plugin install #{@gem_file}")
    unless result
      puts "❌ Plugin installation failed!"
      exit 1
    end
    
    puts "  ✅ Plugin installed successfully"
  end
  
  def install_local_dependencies
    puts "  Installing local Eryph dependencies..."
    
    ruby_client_dir = File.join(@project_root, '..', 'ruby-client')
    unless Dir.exist?(ruby_client_dir)
      puts "    ⚠️  Ruby client directory not found at #{ruby_client_dir}"
      puts "    Attempting to install without local dependencies..."
      return
    end
    
    # Install dependencies in order
    dependencies = [
      'eryph-clientruntime-0.1.1.gem',
      'eryph-compute-0.1.1.gem'
    ]
    
    dependencies.each do |gem_file|
      gem_path = File.join(ruby_client_dir, gem_file)
      if File.exist?(gem_path)
        puts "    Installing #{gem_file}..."
        result = system("vagrant plugin install #{gem_path}")
        if result
          puts "      ✅ Installed #{gem_file}"
        else
          puts "      ⚠️  Failed to install #{gem_file}, continuing..."
        end
      else
        puts "    ⚠️  #{gem_file} not found at #{gem_path}"
      end
    end
  end
  
  def verify_installation
    puts "\n🔍 Verifying installation..."
    
    # Check plugin list
    result = `vagrant plugin list 2>&1`
    unless result.include?(@plugin_name)
      puts "❌ Plugin not found in plugin list!"
      puts "Plugin list output:"
      puts result
      exit 1
    end
    
    # Extract version from listing
    if result =~ /#{@plugin_name} \(([^)]+)\)/
      version = $1
      puts "  ✅ Found #{@plugin_name} version #{version}"
    else
      puts "  ✅ Plugin found in list"
    end
    
    # Test basic functionality
    puts "\n🧪 Testing basic plugin functionality..."
    test_basic_functionality
  end
  
  def test_basic_functionality
    # Create a temporary test directory
    test_dir = File.join(@project_root, 'tmp', 'plugin_test')
    FileUtils.mkdir_p(test_dir)
    
    begin
      Dir.chdir(test_dir) do
        # Create minimal Vagrantfile
        vagrantfile_content = <<~RUBY
          Vagrant.configure("2") do |config|
            config.vm.provider :eryph do |eryph|
              eryph.project = "test-project"
              eryph.parent_gene = "dbosoft/ubuntu-22.04/latest"
            end
          end
        RUBY
        
        File.write('Vagrantfile', vagrantfile_content)
        
        # Test vagrant validate
        puts "  Testing vagrant validate..."
        result = system('vagrant validate > nul 2>&1')
        if result
          puts "    ✅ Vagrantfile validation passed"
        else
          puts "    ⚠️  Vagrantfile validation failed, but plugin is loaded"
        end
        
        # Test vagrant status (should recognize provider)
        puts "  Testing vagrant status..."
        status_output = `vagrant status 2>&1`
        if status_output.include?('eryph') || status_output.include?('not created')
          puts "    ✅ Provider recognized by Vagrant"
        else
          puts "    ⚠️  Provider recognition unclear, but plugin is loaded"
        end
      end
    ensure
      # Clean up test directory
      FileUtils.rm_rf(test_dir)
    end
  end
end

# Run setup if script is executed directly
if __FILE__ == $0
  begin
    setup = VagrantPluginSetup.new
    setup.run
  rescue => e
    puts "\n❌ Setup failed: #{e.message}"
    puts "\nStacktrace:"
    puts e.backtrace.join("\n")
    exit 1
  end
end