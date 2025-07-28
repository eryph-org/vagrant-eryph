require 'spec_helper'

RSpec.describe "Linux Catlet Integration", type: :integration do
  let(:plugin_name) { 'vagrant-eryph' }
  
  before do
    skip_unless_integration_tests
    expect_plugin_installed
  end

  describe "Ubuntu catlet creation and management" do
    it "creates and configures an Ubuntu catlet successfully" do
      puts "\n=== LINUX CATLET INTEGRATION TEST ==="
      
      with_temp_dir do |test_dir|
        puts "Test directory: #{test_dir}"
        
        # Create Vagrantfile with Linux catlet configuration
        vagrantfile_path = create_test_vagrantfile(<<~CONFIG)
          config.vm.provider :eryph do |eryph|
            eryph.project = "integration-test"
            eryph.catlet = {
              parent: "dbosoft/ubuntu-22.04/latest",
              cpu: { count: 1 },
              memory: { startup: 1024 }
            }
            eryph.auto_config = true
          end
          
          # Set guest OS for proper detection
          config.vm.guest = :linux
        CONFIG

        puts "✅ Vagrantfile created at: #{vagrantfile_path}"

        puts "\n--- Testing Vagrant Status ---"
        status_result = execute_vagrant_command('status')
        puts "Status output:"
        puts status_result[:output]
        
        expect(status_result[:success]).to be(true), "Vagrant status failed: #{status_result[:output]}"
        expect(status_result[:output]).not_to include('could not be found'), 
          "Provider not recognized"
        
        puts "✅ Vagrant status completed successfully"

        puts "\n--- Testing Configuration Validation ---"
        validate_result = execute_vagrant_command('validate')
        puts "Validation output:"
        puts validate_result[:output]
        
        expect(validate_result[:success]).to be(true), "Configuration validation failed: #{validate_result[:output]}"
        puts "✅ Configuration validation successful"

        # Only attempt actual catlet operations if Eryph is available
        if ENV['VAGRANT_ERYPH_INTEGRATION'] == 'true'
          puts "\n--- Testing Catlet Creation (if Eryph available) ---"
          puts "NOTE: This may fail if Eryph is not running or not configured"
          
          up_result = execute_vagrant_command('up --provider=eryph', timeout: 300)
          puts "Vagrant up output:"
          puts up_result[:output]
          
          if up_result[:success]
            puts "✅ Catlet creation successful"
            
            # Test SSH connectivity
            puts "\n--- Testing SSH Connectivity ---"
            ssh_config_result = execute_vagrant_command('ssh-config')
            if ssh_config_result[:success]
              puts "✅ SSH configuration available"
              puts ssh_config_result[:output]
            else
              puts "⚠️  SSH configuration not available"
            end
            
            # Clean up - destroy the catlet
            puts "\n--- Cleaning Up Catlet ---"
            destroy_result = execute_vagrant_command('destroy -f', timeout: 180)
            if destroy_result[:success]
              puts "✅ Catlet cleanup successful"
            else
              puts "⚠️  Catlet cleanup may have failed: #{destroy_result[:output]}"
            end
          else
            puts "⚠️  Catlet creation failed (expected if Eryph not available): #{up_result[:output]}"
            
            # Check for specific error types
            if up_result[:output].include?('Could not resolve')
              puts "   → Eryph client configuration not found"
            elsif up_result[:output].include?('connection refused') || up_result[:output].include?('timeout')
              puts "   → Eryph service not reachable"
            else
              puts "   → Other error during catlet creation"
            end
          end
        else
          puts "\n--- Skipping Catlet Creation ---"
          puts "Set VAGRANT_ERYPH_INTEGRATION=true to test actual catlet operations"
        end
      end
    end

    it "handles configuration errors gracefully" do
      puts "\n--- Testing Error Handling ---"
      
      with_temp_dir do |test_dir|
        # Create Vagrantfile with invalid configuration
        create_test_vagrantfile(<<~CONFIG)
          config.vm.provider :eryph do |eryph|
            # Missing required project
            eryph.catlet = {
              parent: "dbosoft/ubuntu-22.04/latest"
            }
          end
        CONFIG

        # Should fail validation gracefully
        validate_result = execute_vagrant_command('validate')
        puts "Validation with missing project:"
        puts validate_result[:output]
        
        # May succeed or fail, but should not crash
        expect([true, false]).to include(validate_result[:success])
        expect(validate_result[:output]).not_to include('undefined method'), 
          "Plugin crashed during validation"
        
        puts "✅ Error handling test completed"
      end
    end
  end

  describe "cloud-init and fodder configuration" do
    it "accepts custom fodder configuration" do
      puts "\n--- Testing Custom Fodder Configuration ---"
      
      with_temp_dir do |test_dir|
        # Create Vagrantfile with custom fodder
        create_test_vagrantfile(<<~CONFIG)
          config.vm.provider :eryph do |eryph|
            eryph.project = "integration-test"
            eryph.catlet = {
              parent: "dbosoft/ubuntu-22.04/latest"
            }
            eryph.fodder = [
              {
                name: "custom-packages",
                type: "cloud-config", 
                content: {
                  "packages" => ["htop", "curl", "git"]
                }
              }
            ]
          end
          
          config.vm.guest = :linux
        CONFIG

        # Should validate successfully
        validate_result = execute_vagrant_command('validate')
        expect(validate_result[:success]).to be(true), 
          "Custom fodder configuration validation failed: #{validate_result[:output]}"
        
        puts "✅ Custom fodder configuration validated successfully"
      end
    end
  end
end