require_relative '../support/test_helper'
require_relative '../../lib/vagrant-eryph/config'

class ConfigTest
  include TestHelper
  
  def run_all
    puts "⚙️  Testing configuration class..."
    
    tests = [
      :test_default_values,
      :test_required_settings,
      :test_auto_config_options,
      :test_resource_settings,
      :test_custom_fodder,
      :test_network_configuration,
      :test_drive_configuration,
      :test_validation_rules,
      :test_configuration_merging
    ]
    
    results = tests.map { |test| run_test_method(test.to_s.gsub('test_', ''), method(test)) }
    
    if results.all?
      puts "✅ All configuration tests passed!"
    else
      puts "❌ Some configuration tests failed"
      false
    end
  end
  
  private
  
  def create_config
    VagrantPlugins::Eryph::Config.new
  end
  
  def test_default_values
    config = create_config
    config.finalize!  # Apply default values
    
    # Test default values
    assert_equal(true, config.auto_config, "auto_config should default to true")
    assert_equal(true, config.enable_winrm, "enable_winrm should default to true")
    assert_equal("vagrant", config.vagrant_password, "vagrant_password should default to 'vagrant'")
    assert_equal(true, config.auto_create_project, "auto_create_project should default to true")
    assert_equal("default", config.config_name, "config_name should default to 'default'")
    assert_equal(:direct, config.ssh_key_injection, "ssh_key_injection should default to :direct")
    
    true
  end
  
  def test_required_settings
    config = create_config
    
    # Test that required settings can be set
    config.project = "test-project"
    config.parent_gene = "dbosoft/ubuntu-22.04/latest"
    
    assert_equal("test-project", config.project, "Project should be settable")
    assert_equal("dbosoft/ubuntu-22.04/latest", config.parent_gene, "Parent gene should be settable")
    
    true
  end
  
  def test_auto_config_options
    config = create_config
    
    # Test auto_config can be disabled
    config.auto_config = false
    assert_equal(false, config.auto_config, "auto_config should be settable to false")
    
    # Test WinRM can be disabled
    config.enable_winrm = false
    assert_equal(false, config.enable_winrm, "enable_winrm should be settable to false")
    
    # Test custom password
    config.vagrant_password = "custom_password"
    assert_equal("custom_password", config.vagrant_password, "vagrant_password should be settable")
    
    # Test SSH key injection methods
    config.ssh_key_injection = :variable
    assert_equal(:variable, config.ssh_key_injection, "ssh_key_injection should accept :variable")
    
    true
  end
  
  def test_resource_settings
    config = create_config
    
    # Test CPU setting
    config.cpu = 4
    assert_equal(4, config.cpu, "CPU should be settable")
    
    # Test memory setting
    config.memory = 4096
    assert_equal(4096, config.memory, "Memory should be settable")
    
    true
  end
  
  def test_custom_fodder
    config = create_config
    
    # Test setting custom fodder
    test_fodder = [
      {
        name: "test-fodder",
        type: "cloud-config",
        content: { "packages" => ["git", "vim"] }
      }
    ]
    
    config.fodder = test_fodder
    assert_equal(test_fodder, config.fodder, "Fodder should be settable")
    
    true
  end
  
  def test_network_configuration
    config = create_config
    
    # Test network settings
    test_networks = [
      { name: "test-network", adapter_name: "eth1" }
    ]
    
    config.networks = test_networks
    assert_equal(test_networks, config.networks, "Networks should be settable")
    
    true
  end
  
  def test_drive_configuration
    config = create_config
    
    # Test drive settings
    test_drives = [
      { name: "data-drive", size: 50 }
    ]
    
    config.drives = test_drives
    assert_equal(test_drives, config.drives, "Drives should be settable")
    
    true
  end
  
  def test_validation_rules
    config = create_config
    mock_machine = create_mock_machine
    
    # Test validation without required settings and finalization
    errors = config.validate(mock_machine)
    assert(errors.is_a?(Hash), "Validation should return a hash")
    assert(!errors['Eryph Provider'].empty?, "Should have validation errors without required settings")
    
    # Test validation with required settings should pass
    config.project = "test-project"
    config.parent_gene = "dbosoft/ubuntu-22.04/latest"
    config.finalize!
    
    errors = config.validate(mock_machine)
    # Validation returns a hash with provider name as key and errors array as value
    assert(errors.is_a?(Hash), "Validation should return a hash")
    assert(errors['Eryph Provider'].empty?, "Validation should pass with required settings")
    
    true
  end
  
  def test_configuration_merging
    config = create_config
    
    # Test that configuration properly handles finalization
    config.project = "test-project"
    config.parent_gene = "dbosoft/ubuntu-22.04/latest"
    
    # Finalize configuration
    config.finalize!
    
    # Test that values are properly finalized
    assert_not_nil(config.project, "Project should be finalized")
    assert_not_nil(config.parent_gene, "Parent gene should be finalized")
    
    true
  end
  
  private
  
  def create_mock_machine
    # Create a minimal mock machine object for validation
    machine = Object.new
    
    # Define methods that Config.validate might call
    def machine.ui
      ui = Object.new
      def ui.error(msg); end
      ui
    end
    
    def machine.config
      config = Object.new
      def config.vm; self; end
      def config.ssh; self; end
      def config.winrm; self; end
      config
    end
    
    def machine.provider_config
      VagrantPlugins::Eryph::Config.new
    end
    
    machine
  end
end