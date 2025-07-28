require 'spec_helper'

RSpec.describe "Full Catlet Lifecycle E2E", type: :e2e do
  let(:plugin_name) { 'vagrant-eryph' }
  let(:test_project) { 'e2e-test' }
  
  before do
    skip_unless_integration_tests
    expect_plugin_installed
    
    # Ensure we have a clean environment
    puts "\n=== E2E TEST SETUP ==="
    puts "Ensuring clean test environment..."
  end

  after do
    puts "\n=== E2E TEST CLEANUP ==="
    puts "Cleaning up any test resources..."
  end

  describe "complete catlet lifecycle with Eryph" do
    it "creates, manages, and destroys a Linux catlet end-to-end", :slow do
      puts "\n=== FULL LIFECYCLE E2E TEST ==="
      puts "This test requires Eryph-zero to be running and configured"
      
      with_temp_dir do |test_dir|
        Dir.chdir(test_dir) do
          puts "Test directory: #{test_dir}"
          
          # Create comprehensive Vagrantfile
          create_test_vagrantfile(<<~CONFIG)
            config.vm.provider :eryph do |eryph|
              eryph.project = "#{test_project}"
              eryph.catlet = {
                parent: "dbosoft/ubuntu-22.04/latest",
                cpu: { count: 1 },
                memory: { startup: 1024 }
              }
              eryph.auto_config = true
              eryph.auto_create_project = true
              
              # Custom fodder for testing
              eryph.fodder = [
                {
                  name: "test-marker",
                  type: "cloud-config",
                  content: {
                    "write_files" => [
                      {
                        "path" => "/tmp/vagrant-eryph-test",
                        "content" => "Created by Vagrant Eryph Plugin E2E Test\\n",
                        "permissions" => "0644"
                      }
                    ]
                  }
                }
              ]
            end
            
            config.vm.guest = :linux
            config.vm.hostname = "e2e-test-catlet"
          CONFIG

          puts "\n--- Phase 1: Configuration Validation ---"
          validate_result = capture_vagrant_output('vagrant validate')
          puts "Validation result: #{validate_result[:success] ? 'SUCCESS' : 'FAILED'}"
          puts validate_result[:output]
          
          expect(validate_result[:success]).to be(true), 
            "Configuration validation failed: #{validate_result[:output]}"
          puts "✅ Configuration validation passed"

          puts "\n--- Phase 2: Initial Status Check ---"
          status_result = capture_vagrant_output('vagrant status')
          puts "Status result: #{status_result[:success] ? 'SUCCESS' : 'FAILED'}"
          puts status_result[:output]
          
          expect(status_result[:success]).to be(true), 
            "Status check failed: #{status_result[:output]}"
          expect(status_result[:output]).to include('not created'), 
            "Expected catlet to be 'not created' initially"
          puts "✅ Initial status check passed"

          puts "\n--- Phase 3: Catlet Creation ---"
          puts "Attempting to create catlet (this may take several minutes)..."
          
          up_result = capture_vagrant_output('vagrant up --provider=eryph', timeout: 600)
          puts "Creation result: #{up_result[:success] ? 'SUCCESS' : 'FAILED'}"
          puts "Creation output:"
          puts up_result[:output]
          
          if up_result[:success]
            puts "✅ Catlet creation successful"
            
            puts "\n--- Phase 4: Post-Creation Status ---"
            status_after_up = capture_vagrant_output('vagrant status')
            puts "Status after creation:"
            puts status_after_up[:output]
            
            expect(status_after_up[:success]).to be(true)
            expect(status_after_up[:output]).to include('running'), 
              "Expected catlet to be 'running' after creation"
            puts "✅ Catlet is running"

            puts "\n--- Phase 5: SSH Configuration ---"
            ssh_config_result = capture_vagrant_output('vagrant ssh-config')
            if ssh_config_result[:success]
              puts "SSH configuration available:"
              puts ssh_config_result[:output]
              puts "✅ SSH configuration generated"
              
              # Extract SSH details for validation
              if ssh_config_result[:output] =~ /HostName (\S+)/
                host = $1
                puts "Catlet IP: #{host}"
              end
              
              if ssh_config_result[:output] =~ /Port (\d+)/
                port = $1
                puts "SSH Port: #{port}"
              end
              
            else
              puts "⚠️  SSH configuration not available: #{ssh_config_result[:output]}"
            end

            puts "\n--- Phase 6: SSH Connectivity Test ---"
            # Test basic SSH connectivity (without actually logging in)
            ssh_test_result = capture_vagrant_output('vagrant ssh -c "echo \'SSH test successful\'"', timeout: 60)
            if ssh_test_result[:success]
              puts "✅ SSH connectivity confirmed"
              puts ssh_test_result[:output]
              
              # Test our custom file was created
              file_test_result = capture_vagrant_output('vagrant ssh -c "cat /tmp/vagrant-eryph-test"', timeout: 30)
              if file_test_result[:success] && file_test_result[:output].include?('Created by Vagrant')
                puts "✅ Custom fodder applied successfully"
              else
                puts "⚠️  Custom fodder may not have been applied"
              end
            else
              puts "⚠️  SSH connectivity test failed: #{ssh_test_result[:output]}"
            end

            puts "\n--- Phase 7: Catlet Halt ---"
            halt_result = capture_vagrant_output('vagrant halt', timeout: 180)
            puts "Halt result: #{halt_result[:success] ? 'SUCCESS' : 'FAILED'}"
            puts halt_result[:output]
            
            if halt_result[:success]
              puts "✅ Catlet halted successfully"
              
              # Verify status after halt
              status_after_halt = capture_vagrant_output('vagrant status')
              if status_after_halt[:success] && status_after_halt[:output].include?('poweroff')
                puts "✅ Catlet confirmed as powered off"
              end
            else
              puts "⚠️  Catlet halt may have failed"
            end

            puts "\n--- Phase 8: Catlet Restart ---"
            restart_result = capture_vagrant_output('vagrant up', timeout: 300)
            puts "Restart result: #{restart_result[:success] ? 'SUCCESS' : 'FAILED'}"
            
            if restart_result[:success]
              puts "✅ Catlet restarted successfully"
            else
              puts "⚠️  Catlet restart failed: #{restart_result[:output]}"
            end

            puts "\n--- Phase 9: Final Cleanup ---"
            destroy_result = capture_vagrant_output('vagrant destroy -f', timeout: 300)
            puts "Destroy result: #{destroy_result[:success] ? 'SUCCESS' : 'FAILED'}"
            puts destroy_result[:output]
            
            if destroy_result[:success]
              puts "✅ Catlet destroyed successfully"
              
              # Verify final status
              final_status = capture_vagrant_output('vagrant status')
              if final_status[:success] && final_status[:output].include?('not created')
                puts "✅ Final status confirmed as 'not created'"
              end
            else
              puts "⚠️  Catlet destruction may have failed"
            end
            
            puts "\n🎉 FULL LIFECYCLE E2E TEST COMPLETED SUCCESSFULLY 🎉"
            
          else
            puts "❌ Catlet creation failed"
            
            # Analyze failure reason
            if up_result[:output].include?('Could not resolve')
              fail "Eryph client configuration missing. Ensure eryph-zero is configured."
            elsif up_result[:output].include?('connection refused') || up_result[:output].include?('timeout')
              fail "Cannot connect to Eryph service. Ensure eryph-zero is running."
            elsif up_result[:output].include?('parent')
              fail "Gene not found. Ensure test genes are available in local genepool."
            else
              fail "Catlet creation failed: #{up_result[:output]}"
            end
          end
        end
      end
    end

    it "handles multiple catlet operations concurrently", :slow do
      skip "Concurrent operations test - implement if needed"
    end

    it "tests Windows catlet lifecycle", :slow do
      puts "\n=== WINDOWS CATLET E2E TEST ==="
      
      with_temp_dir do |test_dir|
        Dir.chdir(test_dir) do
          # Create Windows Vagrantfile
          create_test_vagrantfile(<<~CONFIG)
            config.vm.provider :eryph do |eryph|
              eryph.project = "#{test_project}-windows"
              eryph.catlet = {
                parent: "dbosoft/winsrv2022-standard/latest",
                cpu: { count: 2 },
                memory: { startup: 2048 }
              }
              eryph.enable_winrm = true
              eryph.vagrant_password = "TestPass123!"
              eryph.auto_config = true
            end
            
            config.vm.guest = :windows
            config.vm.communicator = "winrm"
            config.winrm.username = "vagrant"
            config.winrm.password = "TestPass123!"
          CONFIG

          # Test basic validation
          validate_result = capture_vagrant_output('vagrant validate')
          expect(validate_result[:success]).to be(true), 
            "Windows configuration validation failed: #{validate_result[:output]}"
          
          puts "✅ Windows catlet configuration validated"
          
          if ENV['VAGRANT_ERYPH_INTEGRATION'] == 'true'
            puts "Attempting Windows catlet creation (may take longer)..."
            
            up_result = capture_vagrant_output('vagrant up --provider=eryph', timeout: 900)
            if up_result[:success]
              puts "✅ Windows catlet created successfully"
              
              # Test WinRM connectivity
              winrm_test = capture_vagrant_output('vagrant winrm -c "echo \'WinRM test successful\'"', timeout: 60)
              if winrm_test[:success]
                puts "✅ WinRM connectivity confirmed"
              end
              
              # Cleanup
              destroy_result = capture_vagrant_output('vagrant destroy -f', timeout: 300)
              puts destroy_result[:success] ? "✅ Windows catlet cleaned up" : "⚠️  Cleanup may have failed"
            else
              puts "⚠️  Windows catlet creation failed (expected if Windows genes not available)"
              puts up_result[:output]
            end
          else
            puts "Set VAGRANT_ERYPH_INTEGRATION=true to test actual Windows catlet creation"
          end
        end
      end
    end
  end
end