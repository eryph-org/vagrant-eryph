require 'spec_helper'
require_relative '../../lib/vagrant-eryph/provider'
require_relative '../../lib/vagrant-eryph/config'

RSpec.describe VagrantPlugins::Eryph::Provider do
  let(:machine) { create_machine }
  let(:provider) { described_class.new(machine) }
  
  before do
    # Set up machine with provider config
    config = VagrantPlugins::Eryph::Config.new
    config.finalize!
    machine.provider_config = config
  end
  
  describe 'state management' do
    it 'returns not_created state when no catlet ID stored' do
      # Machine has no ID stored - should be not_created
      expect(machine.id).to be_nil
      
      state = provider.state
      expect(state.id).to eq(:not_created)
      expect(state.short_description).to eq("not_created")
    end
    
    it 'handles missing catlet gracefully' do
      # Machine has ID but catlet doesn't exist in Eryph
      machine.id = "nonexistent-catlet-123"
      
      # Mock the static method that would normally query Eryph
      allow(described_class).to receive(:eryph_catlet).with(machine).and_return(nil)
      
      state = provider.state  
      expect(state.id).to eq(:not_created)
    end
    
    it 'maps Eryph catlet states to Vagrant states correctly' do
      machine.id = "test-catlet-123"
      
      # Test different Eryph states (based on actual Eryph API: Stopped, Running, Error, Pending)
      test_cases = [
        { eryph_status: 'running', expected_vagrant_state: :running },
        { eryph_status: 'stopped', expected_vagrant_state: :stopped },
        { eryph_status: 'pending', expected_vagrant_state: :unknown },     # pending could be starting or stopping
        { eryph_status: 'error', expected_vagrant_state: :error },
        { eryph_status: 'unknown_status', expected_vagrant_state: :unknown }
      ]
      
      test_cases.each do |test_case|
        mock_catlet = double('catlet', 
          status: test_case[:eryph_status],
          id: machine.id
        )
        
        allow(described_class).to receive(:eryph_catlet).with(machine).and_return(mock_catlet)
        
        state = provider.state
        expect(state.id).to eq(test_case[:expected_vagrant_state]),
          "Expected #{test_case[:eryph_status]} → #{test_case[:expected_vagrant_state]} but got #{state.id}"
      end
    end
  end
  
  describe 'SSH info extraction' do
    it 'returns nil when catlet is not running' do
      machine.id = "test-catlet-123"
      
      mock_catlet = double('catlet', status: 'stopped', id: machine.id)
      allow(described_class).to receive(:eryph_catlet).with(machine).and_return(mock_catlet)
      
      ssh_info = provider.ssh_info
      expect(ssh_info).to be_nil
    end
    
    it 'extracts IP address from running catlet correctly' do
      machine.id = "test-catlet-123"
      
      # Mock catlet with network configuration like real Eryph returns
      mock_network = double('network',
        floating_port: double('floating_port', 
          ip_v4_addresses: ['192.168.1.100']
        )
      )
      
      mock_catlet = double('catlet',
        status: 'running',
        id: machine.id,
        networks: [mock_network]
      )
      
      allow(described_class).to receive(:eryph_catlet).with(machine).and_return(mock_catlet)
      
      ssh_info = provider.ssh_info
      expect(ssh_info).not_to be_nil
      expect(ssh_info[:host]).to eq('192.168.1.100')
      expect(ssh_info[:port]).to eq(22)
      expect(ssh_info[:username]).to eq('vagrant')
    end
    
    it 'handles catlets without IP addresses gracefully' do
      machine.id = "test-catlet-123"
      
      # Mock catlet that's running but has no IP yet
      mock_catlet = double('catlet',
        status: 'running',
        id: machine.id,
        networks: []
      )
      
      allow(described_class).to receive(:eryph_catlet).with(machine).and_return(mock_catlet)
      
      ssh_info = provider.ssh_info
      expect(ssh_info).to be_nil  # Should wait for IP to be assigned
    end
  end
  
  describe 'provider interface' do
    it 'implements required provider methods' do
      # Provider should implement core Vagrant provider interface
      expect(provider).to respond_to(:state)
      expect(provider).to respond_to(:ssh_info) 
      expect(provider).to respond_to(:action)
      expect(provider).to respond_to(:machine_id_changed)
      
      expect(provider).to be_a(VagrantPlugins::Eryph::Provider)
    end
  end
  
  describe 'real-world error scenarios' do
    it 'propagates API connection errors during state check' do
      machine.id = "test-catlet-123"
      
      # Simulate API connection error
      allow(described_class).to receive(:eryph_catlet).with(machine)
        .and_raise(StandardError.new("Connection refused"))
      
      # Currently the provider does NOT handle API errors gracefully
      # This test documents the current behavior - errors are propagated
      expect { provider.state }.to raise_error(StandardError, "Connection refused")
    end
    
    it 'handles catlet in unexpected state' do
      machine.id = "test-catlet-123"
      
      # Catlet exists but in some new state we don't recognize
      mock_catlet = double('catlet',
        status: 'migrating',  # New state we don't handle
        id: machine.id
      )
      
      allow(described_class).to receive(:eryph_catlet).with(machine).and_return(mock_catlet)
      
      state = provider.state
      expect(state.id).to eq(:unknown)
      expect(state.short_description).to eq("unknown")  # Provider returns state_id.to_s
    end
  end
end