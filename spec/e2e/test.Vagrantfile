# E2E Test Vagrantfile - Ubuntu deployment test
# This file is used by E2E tests to verify actual Vagrant+Eryph integration

Vagrant.configure("2") do |config|
  config.vm.provider :eryph do |eryph|
    # Minimal working configuration
    eryph.parent = "dbosoft/ubuntu-22.04/latest"
    eryph.project = "e2e-test"
    
    # Ensure consistent test environment
    eryph.cpus = 1
    eryph.memory = 1024
    eryph.auto_config = true
  end
  
  # Set VM hostname with timestamp for unique identification
  config.vm.hostname = "vagrant-test-#{Time.now.strftime('%Y%m%d-%H%M%S')}"
  
  # Configure SSH for faster connection
  config.ssh.insert_key = false
  config.vm.boot_timeout = 600
end