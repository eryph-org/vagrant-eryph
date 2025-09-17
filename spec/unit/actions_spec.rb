require 'spec_helper'
require_relative '../../lib/vagrant-eryph/actions'

RSpec.describe VagrantPlugins::Eryph::Actions do

  describe 'Action definitions' do
    it 'defines all expected action methods' do
      expected_actions = [
        :action_halt,
        :action_destroy,
        :action_provision,
        :action_read_ssh_info,
        :action_read_state,
        :action_ssh,
        :action_ssh_run,
        :action_start,
        :action_resume,
        :action_up,
        :action_reload
      ]

      expected_actions.each do |action|
        expect(described_class).to respond_to(action), "Missing action method: #{action}"
      end
    end

    it 'action methods are callable' do
      # Test that action methods exist and are callable (without actually building chains)
      expected_actions = [
        :action_halt,
        :action_destroy,
        :action_provision,
        :action_read_ssh_info,
        :action_read_state,
        :action_ssh,
        :action_ssh_run,
        :action_start,
        :action_resume,
        :action_up,
        :action_reload
      ]

      expected_actions.each do |action|
        expect(described_class).to respond_to(action), "#{action} method should exist"
        expect(described_class.method(action).arity).to eq(0), "#{action} should take no arguments"
      end
    end
  end

  describe 'Autoloaded actions' do
    let(:expected_autoloads) do
      {
        ConnectEryph: 'connect_eryph',
        IsCreated: 'is_created',
        IsState: 'is_state',
        IsStopped: 'is_stopped',
        MessageAlreadyCreated: 'message_already_created',
        MessageNotCreated: 'message_not_created',
        MessageWillNotDestroy: 'message_will_not_destroy',
        CreateCatlet: 'create_catlet',
        DestroyCatlet: 'destroy_catlet',
        StartCatlet: 'start_catlet',
        StopCatlet: 'stop_catlet',
        PrepareCloudInit: 'prepare_cloud_init',
        ReadSSHInfo: 'read_ssh_info',
        ReadState: 'read_state',
      }
    end

    it 'has corresponding files for all autoloaded actions' do
      expected_autoloads.each do |constant, filename|
        file_path = File.join(__dir__, '..', '..', 'lib', 'vagrant-eryph', 'actions', "#{filename}.rb")
        expect(File.exist?(file_path)).to be(true), "Missing action file: #{filename}.rb for constant #{constant}"
      end
    end

    it 'can reference all autoloaded action constants' do
      expected_autoloads.each_key do |constant|
        # Test that the constant exists in the module namespace
        expect(described_class.const_defined?(constant)).to be(true), "Constant #{constant} should be defined"
      end
    end
  end

  describe 'Source code validation' do
    it 'reload action does not reference undefined WaitForState' do
      # Read the action source to verify the fix
      actions_source = File.read(File.join(__dir__, '..', '..', 'lib', 'vagrant-eryph', 'actions.rb'))

      # Should not contain references to undefined WaitForState
      expect(actions_source).not_to include('WaitForState'), "actions.rb should not reference undefined WaitForState"

      # Should use IsStopped instead
      expect(actions_source).to include('IsStopped'), "actions.rb should use IsStopped in reload action"
    end

    it 'start action references IsState which is autoloaded' do
      # Read the action source
      actions_source = File.read(File.join(__dir__, '..', '..', 'lib', 'vagrant-eryph', 'actions.rb'))

      # Should reference IsState
      expect(actions_source).to include('IsState'), "actions.rb should reference IsState"

      # IsState should be in autoload list
      expect(actions_source).to include('autoload :IsState'), "IsState should be autoloaded"
    end
  end
end