require 'spec_helper'
require_relative '../../lib/vagrant-eryph/config'

RSpec.describe VagrantPlugins::Eryph::Config do
  describe 'Vagrant lifecycle simulation' do
    it 'handles the real Vagrant UNSET_VALUE correctly' do
      # This test demonstrates the bug we fixed:
      # Ruby-style setters failed when @catlet was UNSET_VALUE (Symbol)
      # because ||= doesn't work with Vagrant's UNSET_VALUE constant
      
      config = described_class.new
      
      # Before finalize!, instance variables should be UNSET_VALUE
      expect(config.instance_variable_get(:@catlet)).to eq(UNSET_VALUE)
      expect(config.instance_variable_get(:@configuration_name)).to eq(UNSET_VALUE)
      
      # The bug: this would fail because @catlet ||= {} doesn't work when @catlet is :__UNSET__VALUE__
      config.parent = "dbosoft/ubuntu-22.04/latest"
      config.cpus = 2
      config.memory = 2048
      
      # These should work because our setters use ensure_catlet_hash!
      expect(config.parent).to eq("dbosoft/ubuntu-22.04/latest")
      expect(config.cpus).to eq(2)
      expect(config.memory).to eq(2048)
      
      # The catlet hash should be properly initialized
      expect(config.catlet).to be_a(Hash)
      expect(config.catlet[:parent]).to eq("dbosoft/ubuntu-22.04/latest")
      expect(config.catlet[:cpu][:count]).to eq(2)
      expect(config.catlet[:memory][:startup]).to eq(2048)
    end
    
    it 'follows real Vagrant finalize lifecycle' do
      result = simulate_vagrant_lifecycle(described_class)
      
      config = result[:config]
      machine = result[:machine]
      errors = result[:errors]
      
      # After finalize!, UNSET_VALUE fields should be set to defaults
      expect(config.configuration_name).to be_nil  # We fixed this - was 'default'
      expect(config.auto_config).to be(true)
      expect(config.project).to eq('default')
      
      # Should have no validation errors with defaults
      expect_no_validation_errors(config, machine)
    end
    
    it 'validates required configuration correctly' do
      config = described_class.new
      # Don't set parent - this should cause validation error
      config.parent_gene = nil  # Explicitly set to nil 
      config.catlet = {}        # Empty catlet (no parent)
      config.finalize!
      
      machine = create_machine
      
      # Should fail validation - no parent gene or parent in catlet
      expect_validation_error(config, machine, /parent.*required/i)
    end
    
    it 'handles complex configuration transformations' do
      config = described_class.new
      
      # Set up complex configuration using Ruby-style setters
      config.parent = "dbosoft/windows-server/latest"
      config.cpus = 4
      config.memory = 4096
      config.maxmemory = 8192
      config.hostname = "test-server"
      config.enable_secure_boot = true
      config.add_drive "system", size: 100, type: :shared_vhd
      config.add_fodder_gene "dbosoft/guest-services", "windows-install"
      
      config.finalize!
      
      machine = create_machine
      effective_config = config.effective_catlet_configuration(machine)
      
      # Verify complex transformations work correctly
      expect(effective_config[:parent]).to eq("dbosoft/windows-server/latest")
      expect(effective_config[:cpu][:count]).to eq(4)
      expect(effective_config[:memory][:startup]).to eq(4096)
      expect(effective_config[:memory][:maximum]).to eq(8192)
      expect(effective_config[:hostname]).to eq("test-server")
      
      # Should have dynamic_memory and secure_boot capabilities
      capabilities = effective_config[:capabilities]
      expect(capabilities).to include({ name: "dynamic_memory" })
      expect(capabilities).to include({ name: "secure_boot" })
      
      # Should have drive configuration
      drives = effective_config[:drives]
      expect(drives).to include({ name: "system", size: 100, type: "SharedVHD" })
      
      # Should have gene configuration
      genes = effective_config[:genes]
      expect(genes).to include({ name: "gene:dbosoft/guest-services:windows-install" })
      
      expect_no_validation_errors(config, machine)
    end
  end
  
  describe 'error conditions that should have failing tests' do
    it 'fails when Ruby-style setter is called before initialization' do
      # This represents the class of bugs where we don't handle UNSET_VALUE correctly
      config = described_class.new
      
      # This should NOT crash - our ensure_catlet_hash! should handle it
      expect { config.parent = "test-gene" }.not_to raise_error
      expect { config.cpus = 2 }.not_to raise_error
      
      # Values should be accessible  
      expect(config.parent).to eq("test-gene")
      expect(config.cpus).to eq(2)
    end
    
    it 'handles edge case in configuration_name default' do
      # This tests the bug where configuration_name defaulted to 'default' instead of nil
      config = described_class.new
      config.finalize!
      
      # Should be nil, not 'default' - this was the bug
      expect(config.configuration_name).to be_nil
    end
  end
end