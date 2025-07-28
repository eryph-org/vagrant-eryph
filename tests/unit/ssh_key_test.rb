require_relative '../support/test_helper'
require_relative '../../lib/vagrant-eryph/helpers/ssh_key'

class SshKeyTest
  include TestHelper
  
  def run_all
    puts "🔑 Testing SSH key helper..."
    
    tests = [
      :test_ssh_key_class_exists,
      :test_ssh_key_methods_exist
    ]
    
    results = tests.map { |test| run_test_method(test.to_s.gsub('test_', ''), method(test)) }
    
    if results.all?
      puts "✅ All SSH key tests passed!"
    else
      puts "❌ Some SSH key tests failed"
      false
    end
  end
  
  private
  
  def create_helper
    VagrantPlugins::Eryph::Helpers::SSHKey
  end
  
  def test_ssh_key_class_exists
    helper = create_helper
    
    assert_not_nil(helper, "SSH key helper class should exist")
    assert(helper.respond_to?(:generate_key_pair), "Should have generate_key_pair method")
    
    true
  end
  
  def test_ssh_key_methods_exist
    helper = create_helper
    
    # Test that expected methods exist on the class
    expected_methods = [:generate_key_pair, :ensure_key_pair_exists]
    
    expected_methods.each do |method|
      assert(helper.respond_to?(method), "Should respond to #{method}")
    end
    
    true
  end
end