require_relative '../support/test_helper'
require_relative '../mocks/eryph_client_mock'

class LinuxCatletTest
  include TestHelper
  
  def run_all
    puts "🐧 Testing Linux catlet integration..."
    
    tests = [
      :test_ubuntu_catlet_creation,
      :test_ssh_connectivity,
      :test_cloud_init_user_setup,
      :test_custom_packages_installation,
      :test_network_configuration,
      :test_drive_attachment,
      :test_catlet_lifecycle
    ]
    
    results = tests.map { |test| run_test_method(test.to_s.gsub('test_', ''), method(test)) }
    
    if results.all?
      puts "✅ All Linux catlet tests passed!"
    else
      puts "❌ Some Linux catlet tests failed"
      false
    end
  end
  
  private
  
  def test_ubuntu_catlet_creation
    with_temp_dir do |test_dir|
      Dir.chdir(test_dir) do
        # Create Vagrantfile for Ubuntu catlet using new configuration format
        create_test_vagrantfile(<<~CONFIG)
          config.vm.provider :eryph do |eryph|
            eryph.project = "linux-test"
            eryph.catlet = {
              parent: "dbosoft/ubuntu-22.04/latest",
              cpu: { count: 2 },
              memory: { startup: 2048 }
            }
            eryph.auto_config = true
          end
        CONFIG
        
        # Test vagrant status recognizes the configuration
        result = capture_output('vagrant status')
        assert(result[:success], "Vagrant status should work: #{result[:output]}")
        
        # Actually test vagrant up now that we have proper configuration
        puts "      Testing actual catlet creation with vagrant up..."
        up_result = capture_output('vagrant up --provider=eryph', timeout: 600)
        if up_result[:success]
          puts "      ✅ Catlet created successfully"
          
          # Clean up
          capture_output('vagrant destroy -f')
        else
          puts "      ❌ Catlet creation failed: #{up_result[:output]}"
          
          # Check if this is a "provider not found" error (indicates plugin not installed)
          if up_result[:output].include?("could not be found, but was requested")
            puts "      💡 This indicates the vagrant-eryph plugin is not installed. Run: vagrant plugin install"
            return false
          end
          
          # Check if this is an Eryph connectivity issue
          if up_result[:output].include?("Could not resolve") || up_result[:output].include?("No client configuration")
            puts "      💡 This indicates Eryph client configuration issues. Integration tests require running Eryph instance."
            return false
          end
          
          return false
        end
      end
    end
    
    true
  end
  
  def test_ssh_connectivity
    return skip_test("Requires running catlet") unless ENV['VAGRANT_ERYPH_INTEGRATION'] == 'true'
    
    with_temp_dir do |test_dir|
      Dir.chdir(test_dir) do
        create_test_vagrantfile(<<~CONFIG)
          config.vm.provider :eryph do |eryph|
            eryph.project = "ssh-test"
            eryph.catlet = {
              parent: "dbosoft/ubuntu-22.04/latest"
            }
            eryph.auto_config = true
          end
        CONFIG
        
        # Start catlet
        result = capture_output('vagrant up --provider=eryph')
        assert(result[:success], "Should create and start catlet: #{result[:output]}")
        
        # Test SSH connectivity
        ssh_result = capture_output('vagrant ssh -c "echo \'SSH connection successful\'"')
        assert(ssh_result[:success], "Should connect via SSH: #{ssh_result[:output]}")
        assert(ssh_result[:output].include?("SSH connection successful"), 
               "Should execute commands via SSH")
        
        # Clean up
        capture_output('vagrant destroy -f')
      end
    end
    
    true
  end
  
  def test_cloud_init_user_setup
    return skip_test("Requires running catlet") unless ENV['VAGRANT_ERYPH_INTEGRATION'] == 'true'
    
    with_temp_dir do |test_dir|
      Dir.chdir(test_dir) do
        create_test_vagrantfile(<<~CONFIG)
          config.vm.provider :eryph do |eryph|
            eryph.project = "user-setup-test"
            eryph.catlet = {
              parent: "dbosoft/ubuntu-22.04/latest"
            }
            eryph.auto_config = true
          end
        CONFIG
        
        # Start catlet
        result = capture_output('vagrant up --provider=eryph')
        assert(result[:success], "Should create catlet: #{result[:output]}")
        
        # Test that vagrant user exists and has sudo access
        user_check = capture_output('vagrant ssh -c "whoami"')
        assert(user_check[:output].include?("vagrant"), "Should login as vagrant user")
        
        sudo_check = capture_output('vagrant ssh -c "sudo whoami"')
        assert(sudo_check[:output].include?("root"), "Vagrant user should have sudo access")
        
        # Clean up
        capture_output('vagrant destroy -f')
      end
    end
    
    true
  end
  
  def test_custom_packages_installation
    return skip_test("Requires running catlet") unless ENV['VAGRANT_ERYPH_INTEGRATION'] == 'true'
    
    with_temp_dir do |test_dir|
      Dir.chdir(test_dir) do
        create_test_vagrantfile(<<~CONFIG)
          config.vm.provider :eryph do |eryph|
            eryph.project = "packages-test"
            eryph.catlet = {
              parent: "dbosoft/ubuntu-22.04/latest"
            }
            eryph.auto_config = true
            eryph.fodder = [
              {
                name: "custom-packages",
                type: "cloud-config",
                content: {
                  "packages" => ["git", "curl", "vim"],
                  "runcmd" => ["touch /tmp/cloud-init-completed"]
                }
              }
            ]
          end
        CONFIG
        
        # Start catlet
        result = capture_output('vagrant up --provider=eryph')
        assert(result[:success], "Should create catlet: #{result[:output]}")
        
        # Wait for cloud-init to complete
        sleep 30
        
        # Test that packages were installed
        git_check = capture_output('vagrant ssh -c "which git"')
        assert(git_check[:success] && git_check[:output].include?("/usr/bin/git"), 
               "Git should be installed")
        
        vim_check = capture_output('vagrant ssh -c "which vim"')
        assert(vim_check[:success] && vim_check[:output].include?("vim"), 
               "Vim should be installed")
        
        # Test that custom commands ran
        completion_check = capture_output('vagrant ssh -c "ls /tmp/cloud-init-completed"')
        assert(completion_check[:success], "Custom commands should have executed")
        
        # Clean up
        capture_output('vagrant destroy -f')
      end
    end
    
    true
  end
  
  def test_network_configuration
    return skip_test("Network tests require specific Eryph setup") unless ENV['VAGRANT_ERYPH_NETWORK_TEST'] == 'true'
    
    with_temp_dir do |test_dir|
      Dir.chdir(test_dir) do
        create_test_vagrantfile(<<~CONFIG)
          config.vm.provider :eryph do |eryph|
            eryph.project = "network-test"
            eryph.catlet = {
              parent: "dbosoft/ubuntu-22.04/latest",
              networks: [
                { name: "test-network", adapter_name: "eth1" }
              ]
            }
          end
        CONFIG
        
        # Test configuration validation
        result = capture_output('vagrant validate')
        assert(result[:success], "Network configuration should be valid: #{result[:output]}")
        
        puts "      Network configuration validated"
      end
    end
    
    true
  end
  
  def test_drive_attachment
    return skip_test("Drive tests require specific Eryph setup") unless ENV['VAGRANT_ERYPH_DRIVE_TEST'] == 'true'
    
    with_temp_dir do |test_dir|
      Dir.chdir(test_dir) do
        create_test_vagrantfile(<<~CONFIG)
          config.vm.provider :eryph do |eryph|
            eryph.project = "drive-test"
            eryph.catlet = {
              parent: "dbosoft/ubuntu-22.04/latest",
              drives: [
                { name: "data-drive", size: 10 }
              ]
            }
          end
        CONFIG
        
        # Test configuration validation
        result = capture_output('vagrant validate')
        assert(result[:success], "Drive configuration should be valid: #{result[:output]}")
        
        puts "      Drive configuration validated"
      end
    end
    
    true
  end
  
  def test_catlet_lifecycle
    return skip_test("Requires running catlet") unless ENV['VAGRANT_ERYPH_INTEGRATION'] == 'true'
    
    with_temp_dir do |test_dir|
      Dir.chdir(test_dir) do
        create_test_vagrantfile(<<~CONFIG)
          config.vm.provider :eryph do |eryph|
            eryph.project = "lifecycle-test"
            eryph.catlet = {
              parent: "dbosoft/ubuntu-22.04/latest"
            }
            eryph.auto_config = true
          end
        CONFIG
        
        # Test full lifecycle: up -> halt -> up -> destroy
        
        # 1. Create and start
        up_result = capture_output('vagrant up --provider=eryph')
        assert(up_result[:success], "Should create and start: #{up_result[:output]}")
        
        # 2. Check status
        status_result = capture_output('vagrant status')
        assert(status_result[:output].include?("running"), "Should show running status")
        
        # 3. Halt
        halt_result = capture_output('vagrant halt')
        assert(halt_result[:success], "Should halt catlet: #{halt_result[:output]}")
        
        # 4. Check stopped status
        status_result = capture_output('vagrant status')
        assert(status_result[:output].include?("stopped"), "Should show stopped status")
        
        # 5. Restart
        up_result = capture_output('vagrant up')
        assert(up_result[:success], "Should restart catlet: #{up_result[:output]}")
        
        # 6. Destroy
        destroy_result = capture_output('vagrant destroy -f')
        assert(destroy_result[:success], "Should destroy catlet: #{destroy_result[:output]}")
        
        # 7. Check not created status
        status_result = capture_output('vagrant status')
        assert(status_result[:output].include?("not created"), "Should show not created status")
      end
    end
    
    true
  end
end