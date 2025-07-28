require 'rspec'
require 'tempfile'
require 'tmpdir'

# Enable test environment for tests
ENV['VAGRANT_ERYPH_TEST'] = 'true'

# Only enable file mocking for unit tests, NOT integration tests
# Integration tests need real file operations to work with Vagrant
unless ENV['VAGRANT_ERYPH_INTEGRATION'] == 'true'
  ENV['VAGRANT_ERYPH_ENABLE_FILE_MOCKING'] = 'true'
end

# Load Vagrant mocks for testing
require_relative '../tests/support/vagrant_mock'

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
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true
  
  if config.files_to_run.one?
    config.default_formatter = "doc"
  end

  config.order = :random
  Kernel.srand config.seed
end

# Helper methods for integration tests
module IntegrationTestHelpers
  def with_isolated_vagrant_environment
    Dir.mktmpdir("vagrant-eryph-test-") do |temp_dir|
      # Store original VAGRANT_HOME
      original_vagrant_home = ENV["VAGRANT_HOME"]
      
      begin
        # Set up isolated Vagrant environment
        vagrant_home = File.join(temp_dir, ".vagrant.d")
        ENV["VAGRANT_HOME"] = vagrant_home
        FileUtils.mkdir_p(vagrant_home)
        FileUtils.mkdir_p(File.join(vagrant_home, "boxes"))
        
        # Copy global plugins to isolated environment if they exist
        # This allows the isolated environment to access globally installed plugins
        global_vagrant_home = original_vagrant_home || File.join(ENV['USERPROFILE'] || ENV['HOME'], '.vagrant.d')
        
        if Dir.exist?(global_vagrant_home)
          global_plugins_json = File.join(global_vagrant_home, "plugins.json")
          global_gems_dir = File.join(global_vagrant_home, "gems")
          
          # Copy plugins configuration
          if File.exist?(global_plugins_json)
            FileUtils.cp(global_plugins_json, File.join(vagrant_home, "plugins.json"))
            
            if ENV['VAGRANT_ERYPH_DEBUG'] == 'true'
              puts "DEBUG: Copied plugins.json to isolated environment"
            end
          end
          
          # Copy gems directory
          if Dir.exist?(global_gems_dir)
            FileUtils.cp_r(global_gems_dir, vagrant_home)
            
            if ENV['VAGRANT_ERYPH_DEBUG'] == 'true'
              puts "DEBUG: Copied gems directory to isolated environment"
            end
          end
          
          # Copy other essential directories that plugins might need
          %w[rgloader bundler].each do |dir_name|
            global_dir = File.join(global_vagrant_home, dir_name)
            if Dir.exist?(global_dir)
              FileUtils.cp_r(global_dir, vagrant_home)
            end
          end
        end
        
        # Change to temp directory for test
        Dir.chdir(temp_dir) do
          yield temp_dir
        end
      ensure
        # Restore original VAGRANT_HOME
        ENV["VAGRANT_HOME"] = original_vagrant_home
      end
    end
  end

  def with_temp_dir
    with_isolated_vagrant_environment { |dir| yield dir }
  end

  def create_test_vagrantfile(content, dir = Dir.pwd)
    vagrantfile_content = <<~VAGRANTFILE
      Vagrant.configure("2") do |config|
        config.vm.box = "dummy"
        config.vm.box_url = "https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box"
        #{content}
      end
    VAGRANTFILE
    
    vagrantfile_path = File.join(dir, 'Vagrantfile')
    
    # Debug the file creation process
    if ENV['VAGRANT_ERYPH_DEBUG'] == 'true'
      puts "DEBUG: Creating Vagrantfile at #{vagrantfile_path}"
      puts "DEBUG: Content length: #{vagrantfile_content.length}"
      puts "DEBUG: Directory exists: #{Dir.exist?(dir)}"
      puts "DEBUG: Directory writable: #{File.writable?(dir)}"
    end
    
    begin
      File.write(vagrantfile_path, vagrantfile_content)
      
      # Force flush and check immediately
      sleep(0.1) # Brief pause to ensure file system sync
      
      if File.exist?(vagrantfile_path)
        if ENV['VAGRANT_ERYPH_DEBUG'] == 'true'
          puts "DEBUG: File created successfully"
          puts "DEBUG: File size: #{File.size(vagrantfile_path)}"
        end
      else
        # Try alternative approach - create relative to current directory
        if Dir.pwd == dir
          File.write('Vagrantfile', vagrantfile_content)
          sleep(0.1)
          
          if File.exist?('Vagrantfile')
            if ENV['VAGRANT_ERYPH_DEBUG'] == 'true'
              puts "DEBUG: File created with relative path"
            end
            return File.join(dir, 'Vagrantfile')
          end
        end
        
        raise "Failed to create Vagrantfile at #{vagrantfile_path}"
      end
      
    rescue => e
      raise "Error creating Vagrantfile: #{e.message}"
    end
    
    vagrantfile_path
  end

  def capture_vagrant_output(command, timeout: 120)
    require 'timeout'
    require 'open3'
    
    begin
      result = Timeout::timeout(timeout) do
        if Gem.win_platform?
          # Use Open3 for better Windows compatibility with proper environment
          env = ENV.to_hash
          stdout, stderr, status = Open3.capture3(env, 'cmd', '/c', command, 
                                                  chdir: Dir.pwd)
          combined_output = stdout + stderr
          { output: combined_output, success: status.success?, exit_code: status.exitstatus }
        else
          output = `#{command} 2>&1`
          { output: output, success: $?.success?, exit_code: $?.exitstatus }
        end
      end
      result.is_a?(Hash) ? result : { output: result, success: $?.success?, exit_code: $?.exitstatus }
    rescue Timeout::Error
      { output: "Command timed out after #{timeout} seconds", success: false, exit_code: 124 }
    rescue => e
      { output: "Command execution error: #{e.message}", success: false, exit_code: 1 }
    end
  end

  def execute_vagrant_command(command_parts, timeout: 120)
    # Build the full vagrant command
    full_command = "vagrant #{Array(command_parts).join(' ')}"
    
    # Debug output
    if ENV['VAGRANT_ERYPH_DEBUG'] == 'true'
      puts "DEBUG: Executing: #{full_command}"
      puts "DEBUG: Working directory: #{Dir.pwd}"
      puts "DEBUG: VAGRANT_HOME: #{ENV['VAGRANT_HOME']}"
      puts "DEBUG: Vagrantfile exists: #{File.exist?('Vagrantfile')}"
    end
    
    capture_vagrant_output(full_command, timeout: timeout)
  end

  def skip_unless_integration_tests
    # Check multiple ways integration tests might be enabled
    integration_enabled = ENV['VAGRANT_ERYPH_INTEGRATION'] == 'true' || 
                         ENV['INTEGRATION'] == 'true' ||
                         ARGV.include?('--integration')
    
    skip "Integration tests require VAGRANT_ERYPH_INTEGRATION=true" unless integration_enabled
  end

  def expect_plugin_installed
    result = capture_vagrant_output('vagrant plugin list')
    
    # Debug: show what we're getting
    if ENV['VAGRANT_ERYPH_DEBUG'] == 'true'
      puts "DEBUG: Plugin check result: #{result.inspect}"
    end
    
    # Check if the command succeeded and contains our plugin
    if result[:success] && result[:output].include?('vagrant-eryph')
      return true
    end
    
    # Fallback: try multiple approaches to find vagrant
    begin
      # Try with full path to vagrant on Windows
      vagrant_paths = [
        'vagrant',
        'C:/Program Files/Vagrant/bin/vagrant.exe',
        'C:/HashiCorp/Vagrant/bin/vagrant.exe'
      ]
      
      vagrant_paths.each do |vagrant_cmd|
        begin
          if Gem.win_platform?
            direct_output = `"#{vagrant_cmd}" plugin list 2>&1`
          else
            direct_output = `#{vagrant_cmd} plugin list 2>&1`
          end
          
          if $?.success? && direct_output.include?('vagrant-eryph')
            puts "NOTE: Plugin found via direct command (#{vagrant_cmd}), capture_vagrant_output has issues in this environment"
            return true
          end
        rescue
          # Try next path
          next
        end
      end
    rescue
      # Ignore all fallback errors
    end
    
    # If we're in Git Bash and can't reliably detect vagrant, skip instead of fail
    if result[:exit_code] == 127 && ENV['TERM'] && ENV['TERM'].include?('xterm')
      skip "Cannot reliably detect vagrant plugins in Git Bash environment. Please run integration tests from Command Prompt or PowerShell."
    end
    
    fail "vagrant-eryph plugin not installed. Run: rake install"
  end
end

RSpec.configure do |config|
  config.include IntegrationTestHelpers, type: :integration
  config.include IntegrationTestHelpers, type: :installation
  config.include IntegrationTestHelpers, type: :e2e
end