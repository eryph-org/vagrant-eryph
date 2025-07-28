require 'spec_helper'
require_relative '../../lib/vagrant-eryph/helpers/ssh_key'

RSpec.describe VagrantPlugins::Eryph::Helpers::SSHKey do
  let(:mock_machine) { double('machine') }
  let(:mock_ui) { double('ui') }
  let(:mock_data_dir) { double('data_dir') }
  let(:mock_private_key_path) { double('private_key_path') }
  let(:mock_public_key_path) { double('public_key_path') }

  before do
    allow(mock_machine).to receive(:ui).and_return(mock_ui)
    allow(mock_machine).to receive(:data_dir).and_return(mock_data_dir)
    allow(mock_machine).to receive(:name).and_return('test-machine')
    allow(mock_ui).to receive(:info)
    
    allow(mock_data_dir).to receive(:join).with('private_key').and_return(mock_private_key_path)
    allow(mock_data_dir).to receive(:join).with('public_key').and_return(mock_public_key_path)
    allow(mock_data_dir).to receive(:exist?).and_return(true)
    allow(mock_data_dir).to receive(:mkpath)
    
    allow(mock_private_key_path).to receive(:exist?).and_return(false)
    allow(mock_public_key_path).to receive(:exist?).and_return(false)
    allow(mock_private_key_path).to receive(:to_s).and_return('/test/private_key')
    allow(mock_public_key_path).to receive(:to_s).and_return('/test/public_key')
    
    # Mock the class name check for test mode detection
    allow(mock_private_key_path).to receive_message_chain(:class, :name).and_return('MockPath')
  end

  describe 'class methods' do
    it 'exists and can be instantiated' do
      expect(described_class).to be_a Class
    end

    it 'responds to generate_key_pair' do
      expect(described_class).to respond_to(:generate_key_pair)
    end

    it 'responds to ensure_key_pair_exists' do
      expect(described_class).to respond_to(:ensure_key_pair_exists)
    end
  end

  describe 'key pair generation' do
    it 'can generate a key pair with mock machine' do
      result = described_class.generate_key_pair(mock_machine)
      
      expect(result).to be_a Hash
      expect(result).to have_key(:private_key_path)
      expect(result).to have_key(:public_key_path)
      expect(result).to have_key(:private_key)
      expect(result).to have_key(:public_key)
    end

    it 'uses existing keys when available' do
      allow(mock_private_key_path).to receive(:exist?).and_return(true)
      allow(mock_public_key_path).to receive(:exist?).and_return(true)
      
      # Mock File.read for mock paths - this should be handled by the mocking system
      allow(File).to receive(:read).with(mock_private_key_path).and_return('test_private_key')
      allow(File).to receive(:read).with(mock_public_key_path).and_return('test_public_key')
      
      result = described_class.generate_key_pair(mock_machine)
      
      expect(result[:private_key]).to eq('test_private_key')
      expect(result[:public_key]).to eq('test_public_key')
    end
  end

  describe 'key pair management' do
    it 'can ensure key pair exists with mock machine' do
      result = described_class.ensure_key_pair_exists(mock_machine)
      
      expect(result).to be_a Hash
      expect(result).to have_key(:private_key)
      expect(result).to have_key(:public_key)
    end

    it 'returns existing key data when keys exist' do
      allow(mock_private_key_path).to receive(:exist?).and_return(true)
      allow(mock_public_key_path).to receive(:exist?).and_return(true)
      allow(File).to receive(:read).with(mock_private_key_path).and_return('existing_private_key')
      allow(File).to receive(:read).with(mock_public_key_path).and_return('existing_public_key')
      
      result = described_class.ensure_key_pair_exists(mock_machine)
      
      expect(result[:private_key]).to eq('existing_private_key')
      expect(result[:public_key]).to eq('existing_public_key')
    end
  end

  describe 'error handling' do
    it 'handles missing data directory gracefully' do
      allow(mock_data_dir).to receive(:exist?).and_return(false)
      
      expect { described_class.generate_key_pair(mock_machine) }.not_to raise_error
    end
  end
end