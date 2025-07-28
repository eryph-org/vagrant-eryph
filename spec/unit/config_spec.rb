require 'spec_helper'
require_relative '../../lib/vagrant-eryph/config'

RSpec.describe VagrantPlugins::Eryph::Config do
  let(:config) { described_class.new }
  let(:mock_machine) { double('machine') }

  before do
    allow(mock_machine).to receive(:config).and_return(double('machine_config', vm: double('vm_config')))
    allow(mock_machine).to receive(:name).and_return('default')
  end

  describe 'default values' do
    before { config.finalize! }

    it 'sets correct default values' do
      expect(config.auto_config).to be true
      expect(config.enable_winrm).to be true
      expect(config.vagrant_password).to eq 'vagrant'
      expect(config.auto_create_project).to be true
      expect(config.configuration_name).to eq 'default'
      expect(config.ssh_key_injection).to eq :direct
      expect(config.catlet).to eq({})
      expect(config.fodder).to eq([])
    end

    it 'sets legacy default parent_gene' do
      expect(config.parent_gene).to eq 'dbosoft/ubuntu:22.04'
    end
  end

  describe 'configuration assignment' do
    it 'allows setting required configuration' do
      config.project = 'test-project'
      config.catlet = { parent: 'dbosoft/ubuntu-22.04/latest' }
      
      expect(config.project).to eq 'test-project'
      expect(config.catlet[:parent]).to eq 'dbosoft/ubuntu-22.04/latest'
    end

    it 'allows setting auto-config options' do
      config.auto_config = false
      config.enable_winrm = false
      config.vagrant_password = 'custom_password'
      config.ssh_key_injection = :variable

      expect(config.auto_config).to be false
      expect(config.enable_winrm).to be false
      expect(config.vagrant_password).to eq 'custom_password'
      expect(config.ssh_key_injection).to eq :variable
    end

    it 'allows setting catlet resource configuration' do
      config.catlet = {
        parent: 'dbosoft/ubuntu-22.04/latest',
        cpu: { count: 4 },
        memory: { startup: 4096 }
      }
      
      expect(config.catlet[:cpu]).to eq({ count: 4 })
      expect(config.catlet[:memory]).to eq({ startup: 4096 })
    end

    it 'allows setting custom fodder' do
      test_fodder = [
        {
          name: 'test-fodder',
          type: 'cloud-config',
          content: { 'packages' => ['git', 'vim'] }
        }
      ]
      
      config.fodder = test_fodder
      expect(config.fodder).to eq test_fodder
    end

    it 'allows setting network and drive configuration in catlet hash' do
      config.catlet = {
        parent: 'dbosoft/ubuntu-22.04/latest',
        networks: [{ name: 'test-network', adapter_name: 'eth1' }],
        drives: [{ name: 'data-drive', size: 50 }]
      }
      
      expect(config.catlet[:networks]).to eq([{ name: 'test-network', adapter_name: 'eth1' }])
      expect(config.catlet[:drives]).to eq([{ name: 'data-drive', size: 50 }])
    end
  end

  describe 'validation' do
    it 'fails validation without required parent' do
      # Don't set parent in catlet or parent_gene, leave both empty
      config.parent_gene = nil  # Explicitly set to nil to trigger validation error
      config.catlet = {}  # Empty catlet hash
      config.finalize!
      errors = config.validate(mock_machine)
      
      expect(errors).to be_a Hash
      expect(errors['Eryph Provider']).not_to be_empty
    end

    it 'passes validation with required settings' do
      config.project = 'test-project'
      config.catlet = { parent: 'dbosoft/ubuntu-22.04/latest' }
      config.finalize!
      
      errors = config.validate(mock_machine)
      expect(errors['Eryph Provider']).to be_empty
    end

    it 'validates fodder structure' do
      config.fodder = 'invalid'  # Should be array
      config.finalize!
      
      errors = config.validate(mock_machine)
      expect(errors['Eryph Provider']).to include('fodder must be an array')
    end

    it 'validates ssh_key_injection options' do
      config.ssh_key_injection = :invalid
      config.finalize!
      
      errors = config.validate(mock_machine)
      expect(errors['Eryph Provider']).to include('ssh_key_injection must be :direct or :variable')
    end

    it 'validates numeric CPU values' do
      config.cpu = -1
      config.finalize!
      
      errors = config.validate(mock_machine)
      expect(errors['Eryph Provider']).to include('cpu must be a positive integer')
    end

    it 'validates numeric memory values' do
      config.memory = 'invalid'
      config.finalize!
      
      errors = config.validate(mock_machine)
      expect(errors['Eryph Provider']).to include('memory must be a positive integer (MB)')
    end
  end

  describe 'helper methods' do
    before do
      allow(mock_machine).to receive(:config).and_return(
        double('machine_config', vm: double('vm_config', hostname: 'test-hostname'))
      )
    end

    describe '#windows_catlet?' do
      it 'detects Windows catlets by gene name' do
        # Test with default Ubuntu gene (should be false)
        config.finalize!
        expect(config.windows_catlet?).to be false
        
        # Test with explicit Windows genes
        config.parent_gene = 'dbosoft/winsrv2022-standard/latest'
        expect(config.windows_catlet?).to be true
        
        config.parent_gene = 'dbosoft/win-starter:2022'
        expect(config.windows_catlet?).to be true
        
        # Test with catlet hash taking precedence  
        config.catlet = { parent: 'dbosoft/windows-server/latest' }
        expect(config.windows_catlet?).to be true
        
        config.catlet = { parent: 'dbosoft/ubuntu-22.04/latest' }
        expect(config.windows_catlet?).to be false
      end
    end

    describe '#effective_catlet_name' do
      it 'uses catlet_name if set' do
        config.catlet_name = 'custom-name'
        config.finalize!
        expect(config.effective_catlet_name(mock_machine)).to eq 'custom-name'
      end

      it 'falls back to hostname if catlet_name not set' do
        config.finalize!
        expect(config.effective_catlet_name(mock_machine)).to eq 'test-hostname'
      end

      it 'falls back to machine name if neither catlet_name nor hostname set' do
        allow(mock_machine.config.vm).to receive(:hostname).and_return(nil)
        config.finalize!
        expect(config.effective_catlet_name(mock_machine)).to eq 'default'
      end
    end

    describe '#effective_catlet_configuration' do
      it 'builds configuration from catlet hash' do
        config.project = 'test-project'
        config.catlet = { parent: 'dbosoft/ubuntu-22.04/latest', cpu: { count: 4 } }
        config.catlet_name = 'test-catlet'
        config.finalize!
        
        result = config.effective_catlet_configuration(mock_machine)
        
        expect(result[:name]).to eq 'test-catlet'
        expect(result[:project]).to eq 'test-project'
        expect(result[:parent]).to eq 'dbosoft/ubuntu-22.04/latest'
        expect(result[:cpu]).to eq({ count: 4 })
      end

      it 'merges legacy configuration when catlet hash is empty' do
        config.project = 'test-project'
        config.parent_gene = 'dbosoft/ubuntu-22.04/latest'
        config.cpu = 4
        config.memory = 2048
        config.finalize!
        
        result = config.effective_catlet_configuration(mock_machine)
        
        expect(result[:parent]).to eq 'dbosoft/ubuntu-22.04/latest'
        expect(result[:cpu]).to eq 4
        expect(result[:memory]).to eq 2048
      end

      it 'prioritizes catlet hash over legacy configuration' do
        config.project = 'test-project'
        config.catlet = { parent: 'dbosoft/newer-gene/latest', cpu: { count: 8 } }
        config.parent_gene = 'dbosoft/older-gene/latest'  # Legacy - should be ignored
        config.cpu = 4  # Legacy - should be ignored
        config.finalize!
        
        result = config.effective_catlet_configuration(mock_machine)
        
        expect(result[:parent]).to eq 'dbosoft/newer-gene/latest'
        expect(result[:cpu]).to eq({ count: 8 })
      end
    end
  end
end