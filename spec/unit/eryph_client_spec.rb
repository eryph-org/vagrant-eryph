require 'spec_helper'
require_relative '../../lib/vagrant-eryph/helpers/eryph_client'
require_relative '../../lib/vagrant-eryph/config'

RSpec.describe VagrantPlugins::Eryph::Helpers::EryphClient do
  let(:machine) { create_machine }
  let(:config) do
    config = VagrantPlugins::Eryph::Config.new
    config.auto_create_project = true
    config.finalize!
    config
  end
  let(:client_helper) { described_class.new(machine) }

  before do
    machine.provider_config = config

    # Mock the UI
    allow(machine.ui).to receive(:info)
    allow(machine.ui).to receive(:error)
  end

  describe '#create_project' do
    let(:project_name) { 'test-project' }
    let(:operation_id) { 'op-123' }
    let(:project_id) { 'proj-456' }

    it 'creates project and fetches operation with projects expanded' do
      # Mock objects
      mock_operation = double('operation', id: operation_id)
      mock_wait_result = double('operation_result', id: operation_id, completed?: true)
      mock_project = double('project', id: project_id, name: project_name)
      mock_final_operation = double('final_operation')
      mock_final_result = double('final_result', project: mock_project)
      mock_client = double('client')
      mock_projects_api = double('projects_api')
      mock_operations_api = double('operations_api')

      # Mock the client creation
      allow(client_helper).to receive(:client).and_return(mock_client)
      allow(mock_client).to receive(:projects).and_return(mock_projects_api)
      allow(mock_client).to receive(:operations).and_return(mock_operations_api)

      # Mock project creation API call
      allow(mock_projects_api).to receive(:projects_create).and_return(mock_operation)

      # Mock wait_for_operation
      allow(client_helper).to receive(:wait_for_operation).with(operation_id).and_return(mock_wait_result)

      # Mock final operation fetch with projects expanded
      allow(mock_operations_api).to receive(:operations_get)
        .with(operation_id, expand: 'projects')
        .and_return(mock_final_operation)

      # Mock final OperationResult creation (stub the class)
      operation_result_class = double('OperationResult')
      stub_const('::Eryph::Compute::OperationResult', operation_result_class)
      allow(operation_result_class).to receive(:new)
        .with(mock_final_operation, mock_client)
        .and_return(mock_final_result)

      result = client_helper.create_project(project_name)

      # Verify the flow
      expect(mock_projects_api).to have_received(:projects_create)
      expect(client_helper).to have_received(:wait_for_operation).with(operation_id)
      expect(mock_operations_api).to have_received(:operations_get)
        .with(operation_id, expand: 'projects')
      expect(operation_result_class).to have_received(:new)
        .with(mock_final_operation, mock_client)

      # Result should be the project from the expanded operation
      expect(result).to eq(mock_project)
    end

    it 'raises error when project not found in expanded operation' do
      # Mock objects for this test
      mock_operation = double('operation', id: operation_id)
      mock_wait_result = double('operation_result', id: operation_id, completed?: true)
      mock_final_operation = double('final_operation')
      mock_final_result = double('final_result', project: nil)  # No project!
      mock_client = double('client')
      mock_projects_api = double('projects_api')
      mock_operations_api = double('operations_api')

      # Setup mocks
      allow(client_helper).to receive(:client).and_return(mock_client)
      allow(mock_client).to receive(:projects).and_return(mock_projects_api)
      allow(mock_client).to receive(:operations).and_return(mock_operations_api)
      allow(mock_projects_api).to receive(:projects_create).and_return(mock_operation)
      allow(client_helper).to receive(:wait_for_operation).with(operation_id).and_return(mock_wait_result)
      allow(mock_operations_api).to receive(:operations_get)
        .with(operation_id, expand: 'projects')
        .and_return(mock_final_operation)

      operation_result_class = double('OperationResult')
      stub_const('::Eryph::Compute::OperationResult', operation_result_class)
      allow(operation_result_class).to receive(:new)
        .with(mock_final_operation, mock_client)
        .and_return(mock_final_result)

      expect do
        client_helper.create_project(project_name)
      end.to raise_error(/Project creation completed but project not found/)
    end

    it 'raises error when operation fails' do
      # Mock objects for this test
      mock_operation = double('operation', id: operation_id)
      mock_wait_result = double('operation_result', id: operation_id, completed?: false, status_message: 'Operation failed')
      mock_client = double('client')
      mock_projects_api = double('projects_api')

      # Setup mocks
      allow(client_helper).to receive(:client).and_return(mock_client)
      allow(mock_client).to receive(:projects).and_return(mock_projects_api)
      allow(mock_projects_api).to receive(:projects_create).and_return(mock_operation)
      allow(client_helper).to receive(:wait_for_operation).with(operation_id).and_return(mock_wait_result)

      expect do
        client_helper.create_project(project_name)
      end.to raise_error(/Project creation failed: Operation failed/)
    end
  end

  describe '#ensure_project_exists' do
    let(:project_name) { 'test-project' }
    let(:mock_project) { double('project', id: 'proj-123', name: project_name) }

    context 'when project exists' do
      before do
        allow(client_helper).to receive(:get_project).with(project_name).and_return(mock_project)
        allow(client_helper).to receive(:create_project)
      end

      it 'returns existing project without creating new one' do
        result = client_helper.ensure_project_exists(project_name)

        expect(result).to eq(mock_project)
        expect(client_helper).not_to have_received(:create_project)
      end
    end

    context 'when project does not exist and auto_create_project is enabled' do
      before do
        allow(client_helper).to receive(:get_project).with(project_name).and_return(nil)
        allow(client_helper).to receive(:create_project).with(project_name).and_return(mock_project)
      end

      it 'creates project automatically' do
        result = client_helper.ensure_project_exists(project_name)

        expect(client_helper).to have_received(:create_project).with(project_name)
        expect(result).to eq(mock_project)
      end
    end

    context 'when project does not exist and auto_create_project is disabled' do
      before do
        config.auto_create_project = false
        allow(client_helper).to receive(:get_project).with(project_name).and_return(nil)
      end

      it 'raises error' do
        expect do
          client_helper.ensure_project_exists(project_name)
        end.to raise_error(/not found and auto_create_project is disabled/)
      end
    end
  end
end