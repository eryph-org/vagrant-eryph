# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/vagrant-eryph/helpers/eryph_client'

RSpec.describe VagrantPlugins::Eryph::Helpers::EryphClient, 'log message display' do
  let(:machine) { create_machine }
  let(:config) { double('config') }
  let(:ui) { double('ui') }
  let(:client) { described_class.new(machine) }

  before do
    allow(machine).to receive(:provider_config).and_return(config)
    allow(machine).to receive(:ui).and_return(ui)
    allow(ui).to receive(:info)
    allow(ui).to receive(:error)
    allow(ui).to receive(:success)
    allow(ui).to receive(:detail)
  end

  describe '#wait_for_operation log message handling' do
    let(:mock_compute_client) { double('compute_client') }
    let(:operation_id) { 'test-operation-123' }

    before do
      allow(client).to receive(:client).and_return(mock_compute_client)
    end

    it 'displays log messages like .NET client verbose output' do
      # Mock the client.wait_for_operation call to simulate log entries
      expect(mock_compute_client).to receive(:wait_for_operation).with(
        operation_id,
        timeout: 600
      ).and_yield(:log_entry, mock_log_entry('Pulling volume gene:dbosoft/winsrv2019-standard/20250911:sda (hyperv/amd64) (234 MiB / 4604 MiB) => 5,1 % completed'))
       .and_yield(:log_entry, mock_log_entry('Pulling volume gene:dbosoft/winsrv2019-standard/20250911:sda (hyperv/amd64) (464 MiB / 4604 MiB) => 10,1 % completed'))
       .and_yield(:log_entry, mock_log_entry('Configure Catlet CPU count: 2'))
       .and_yield(:resource_new, mock_resource('Catlet', 'catlet-123'))
       .and_return(mock_successful_result)

      # Capture UI messages to verify log message display
      ui_messages = []
      allow(ui).to receive(:info) { |msg| ui_messages << msg }

      # Call the method
      client.wait_for_operation(operation_id)

      # Should show log messages directly without operation ID prefix

      expect(ui_messages).to include("Pulling volume gene:dbosoft/winsrv2019-standard/20250911:sda (hyperv/amd64) (234 MiB / 4604 MiB) => 5,1 % completed")
      expect(ui_messages).to include("Pulling volume gene:dbosoft/winsrv2019-standard/20250911:sda (hyperv/amd64) (464 MiB / 4604 MiB) => 10,1 % completed")
      expect(ui_messages).to include("Configure Catlet CPU count: 2")
    end

    it 'handles log entries without messages gracefully' do
      # Mock log entry without message
      expect(mock_compute_client).to receive(:wait_for_operation).with(
        operation_id,
        timeout: 600
      ).and_yield(:log_entry, mock_log_entry_without_message)
       .and_return(mock_successful_result)

      # Should not crash when log entry has no message
      expect { client.wait_for_operation(operation_id) }.not_to raise_error
    end
  end

  private

  def mock_log_entry(message)
    double('log_entry',
      message: message,
      respond_to?: ->(method) { [:message].include?(method) }
    )
  end

  def mock_log_entry_without_message
    double('log_entry_without_message',
      message: nil,
      respond_to?: ->(method) { [:message].include?(method) }
    )
  end

  def mock_resource(resource_type, resource_id)
    double('resource',
      resource_type: resource_type,
      resource_id: resource_id,
      id: resource_id
    )
  end

  def mock_successful_result
    double('operation_result',
      completed?: true,
      failed?: false,
      status: 'Completed'
    )
  end
end