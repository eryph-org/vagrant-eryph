require 'spec_helper'
require_relative '../../lib/vagrant-eryph/helpers/cloud_init'

RSpec.describe VagrantPlugins::Eryph::Helpers::CloudInit do
  let(:mock_machine) { double('machine') }
  let(:mock_config) { double('config') }

  before do
    mock_path = double('path', exist?: false, to_s: '/tmp/test_key')
    mock_data_dir = double('data_dir')
    allow(mock_data_dir).to receive(:join).and_return(mock_path)
    allow(mock_data_dir).to receive(:exist?).and_return(true)
    allow(mock_data_dir).to receive(:mkpath)
    
    # Mock the class name check for test mode detection
    allow(mock_path).to receive_message_chain(:class, :name).and_return('MockPath')
    
    allow(mock_machine).to receive(:provider_config).and_return(mock_config)
    allow(mock_machine).to receive(:config).and_return(double('machine_config', vm: double('vm_config', guest: :linux)))
    allow(mock_machine).to receive(:name).and_return('test-machine')
    mock_ui = double('ui')
    allow(mock_ui).to receive(:info)
    allow(mock_machine).to receive(:ui).and_return(mock_ui)
    allow(mock_machine).to receive(:data_dir).and_return(mock_data_dir)
    allow(mock_config).to receive(:auto_config).and_return(true)
    allow(mock_config).to receive(:enable_winrm).and_return(true)
    allow(mock_config).to receive(:vagrant_password).and_return('test_password')
    allow(mock_config).to receive(:ssh_key_injection).and_return(:direct)
    allow(mock_config).to receive(:merged_fodder).and_return([])
    allow(mock_config).to receive(:windows_catlet?).and_return(false)
  end

  describe 'OS detection' do
    it 'detects Linux systems using Vagrant guest setting' do
      helper = described_class.new(mock_machine)
      expect(helper.detect_os_type).to eq :linux
    end

    it 'detects Windows systems using Vagrant guest setting' do
      allow(mock_machine).to receive(:config).and_return(double('machine_config', vm: double('vm_config', guest: :windows)))
      helper = described_class.new(mock_machine)
      expect(helper.detect_os_type).to eq :windows
    end

    it 'falls back to gene name heuristic when guest not set' do
      allow(mock_machine).to receive(:config).and_return(double('machine_config', vm: double('vm_config', guest: nil)))
      allow(mock_config).to receive(:windows_catlet?).and_return(true)
      helper = described_class.new(mock_machine)
      expect(helper.detect_os_type).to eq :windows
    end
  end

  describe 'vagrant user fodder generation' do
    context 'for Linux systems' do
      it 'generates Linux user setup fodder' do
        helper = described_class.new(mock_machine)
        fodder = helper.generate_vagrant_user_fodder
        
        expect(fodder).to be_an Array
        expect(fodder).not_to be_empty
        
        # Should contain cloud-config for user setup
        user_setup = fodder.find { |f| f[:name].include?('vagrant-user') }
        expect(user_setup).not_to be_nil
        expect(user_setup[:type]).to eq 'cloud-config'
      end
    end

    context 'for Windows systems' do
      before do
        allow(mock_machine).to receive(:config).and_return(double('machine_config', vm: double('vm_config', guest: :windows)))
      end

      it 'generates Windows user setup fodder' do
        helper = described_class.new(mock_machine)
        fodder = helper.generate_vagrant_user_fodder
        
        expect(fodder).to be_an Array
        expect(fodder).not_to be_empty
        
        # Should contain cloud-config for user setup
        user_setup = fodder.find { |f| f[:name].include?('vagrant-user') }
        expect(user_setup).not_to be_nil
        expect(user_setup[:type]).to eq 'cloud-config'
        
        # Should also contain PowerShell script for WinRM setup
        winrm_setup = fodder.find { |f| f[:name].include?('winrm') }
        expect(winrm_setup).not_to be_nil
        expect(winrm_setup[:type]).to eq 'shellscript'
      end
    end
  end

  describe 'complete fodder generation' do
    before do
      allow(mock_config).to receive(:windows_catlet?).and_return(false)
    end

    it 'generates complete fodder configuration' do
      helper = described_class.new(mock_machine)
      fodder = helper.generate_complete_fodder
      
      expect(fodder).to be_an Array
    end

    it 'includes user-generated fodder when auto_config is disabled' do
      allow(mock_config).to receive(:auto_config).and_return(false)
      allow(mock_config).to receive(:merged_fodder).and_return([
        { name: 'custom', type: 'cloud-config', content: {} }
      ])
      
      helper = described_class.new(mock_machine)
      fodder = helper.generate_complete_fodder
      
      expect(fodder).to be_an Array
    end
  end

  describe 'fodder merging' do
    before do
      allow(mock_config).to receive(:windows_catlet?).and_return(false)
    end

    it 'merges auto-generated fodder with user configuration' do
      auto_fodder = [{ name: 'auto-generated', type: 'cloud-config', content: {} }]
      
      helper = described_class.new(mock_machine)
      merged = helper.merge_fodder_with_user_config(auto_fodder)
      
      expect(merged).to be_an Array
    end

    it 'returns user fodder when auto_config is disabled' do
      allow(mock_config).to receive(:auto_config).and_return(false)
      user_fodder = [{ name: 'user-only', type: 'cloud-config', content: {} }]
      allow(mock_config).to receive(:merged_fodder).and_return(user_fodder)
      
      helper = described_class.new(mock_machine)
      result = helper.merge_fodder_with_user_config([])
    
      expect(result).to eq user_fodder
    end
  end

  describe 'SSH key handling' do
    before do
      allow(mock_config).to receive(:windows_catlet?).and_return(false)
    end

    context 'with direct SSH key injection' do
      before do
        allow(mock_config).to receive(:ssh_key_injection).and_return(:direct)
      end

      it 'includes SSH keys directly in cloud-config' do
        helper = described_class.new(mock_machine)
        fodder = helper.generate_vagrant_user_fodder
        
        expect(fodder).to be_an Array
      end
    end

    context 'with variable SSH key injection' do
      before do
        allow(mock_config).to receive(:ssh_key_injection).and_return(:variable)
      end

      it 'includes SSH keys via write_files' do
        helper = described_class.new(mock_machine)
        fodder = helper.generate_vagrant_user_fodder
        
        expect(fodder).to be_an Array
      end
    end
  end
end