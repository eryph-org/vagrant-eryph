require_relative '../support/test_helper'
require_relative '../../lib/vagrant-eryph/helpers/cloud_init'

class CloudInitTest
  include TestHelper
  
  def run_all
    puts "☁️  Testing cloud-init helper..."
    
    tests = [
      :test_os_detection,
      :test_vagrant_user_fodder_generation,
      :test_complete_fodder_generation,
      :test_fodder_merging
    ]
    
    results = tests.map { |test| run_test_method(test.to_s.gsub('test_', ''), method(test)) }
    
    if results.all?
      puts "✅ All cloud-init tests passed!"
    else
      puts "❌ Some cloud-init tests failed"
      false
    end
  end
  
  private
  
  def create_helper(is_windows = false)
    mock_machine = MockMachine.new
    mock_machine.instance_variable_set(:@provider_config, create_mock_config(is_windows))
    VagrantPlugins::Eryph::Helpers::CloudInit.new(mock_machine)
  end
  
  def create_mock_config(is_windows = false)
    config = Object.new
    def config.auto_config; true; end
    def config.enable_winrm; true; end
    def config.vagrant_password; "test_password"; end
    def config.ssh_key_injection; :direct; end
    config.define_singleton_method(:windows_catlet?) { is_windows }
    def config.merged_fodder(auto_fodder); auto_fodder; end
    config
  end
  
  def test_os_detection
    # Test Linux detection (default config)
    linux_helper = create_helper(false)  # false = not windows
    os_type = linux_helper.detect_os_type
    assert_equal(:linux, os_type, "Should detect Linux")
    
    # Test Windows detection
    windows_helper = create_helper(true)  # true = windows
    os_type = windows_helper.detect_os_type
    assert_equal(:windows, os_type, "Should detect Windows")
    
    true
  end
  
  def test_vagrant_user_fodder_generation
    # Test Linux fodder generation
    linux_helper = create_helper(false)
    linux_fodder = linux_helper.generate_vagrant_user_fodder
    
    # Should generate fodder for Linux
    assert(linux_fodder.is_a?(Array), "Should return array of fodder")
    
    # Test Windows fodder generation  
    windows_helper = create_helper(true)
    windows_fodder = windows_helper.generate_vagrant_user_fodder
    
    # Should generate fodder for Windows
    assert(windows_fodder.is_a?(Array), "Should return array of fodder")
    
    true
  end
  
  def test_complete_fodder_generation
    helper = create_helper
    
    # Test complete fodder generation
    complete_fodder = helper.generate_complete_fodder
    
    assert(complete_fodder.is_a?(Array), "Should return array of fodder")
    
    true
  end
  
  def test_fodder_merging
    helper = create_helper
    
    # Test basic fodder merging functionality
    auto_fodder = [{ name: "auto-generated", type: "cloud-config", content: {} }]
    merged = helper.merge_fodder_with_user_config(auto_fodder)
    
    assert(merged.is_a?(Array), "Should return merged fodder array")
    
    true
  end
end