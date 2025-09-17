# frozen_string_literal: true

require 'eryph'
require 'set'
require 'log4r'
require 'yaml'
require_relative '../errors'

module VagrantPlugins
  module Eryph
    module Helpers
      class EryphClient
        # Permission scopes for minimal access
        SCOPES = {          
          # Catlet-specific scopes
          CATLETS_READ: 'compute:catlets:read',
          CATLETS_WRITE: 'compute:catlets:write',
          CATLETS_CONTROL: 'compute:catlets:control',
          
          # Project-specific scopes
          PROJECTS_READ: 'compute:projects:read',
          PROJECTS_WRITE: 'compute:projects:write'
        }.freeze

        def initialize(machine)
          @machine = machine
          @config = machine.provider_config
          @ui = machine.ui
          @client = nil
          @logger = Log4r::Logger.new('vagrant::eryph::client')
        end

        def client(scopes = nil)
          # Create a new client if scopes changed or client doesn't exist
          requested_scopes = scopes || [SCOPES[:CATLETS_WRITE], SCOPES[:PROJECTS_WRITE]]
          
          if @client.nil? || @last_scopes != requested_scopes
            @client = create_client(requested_scopes)
            @last_scopes = requested_scopes
          end
          
          @client
        end

        def list_catlets
          handle_api_errors do
            response = client([SCOPES[:CATLETS_READ]]).catlets.catlets_list
            # CatletList object contains 'value' array with actual catlets
            response.respond_to?(:value) ? response.value : []
          end
        rescue Errors::EryphError
          [] # Return empty array on API errors to allow graceful degradation
        end

        def get_catlet(catlet_id)
          handle_api_errors do
            client([SCOPES[:CATLETS_READ]]).catlets.catlets_get(catlet_id)
          end
        rescue Errors::EryphError
          nil # Return nil on errors to allow graceful handling
        end

        def create_catlet(catlet_config_hash)
          SecureRandom.uuid
          @ui.info("Creating catlet: #{catlet_config_hash[:name]}")

          # Validate configuration first
          raise 'Catlet configuration validation failed' unless validate_catlet_config(catlet_config_hash)

          # Create proper NewCatletRequest object with hash configuration
          request_obj = ::Eryph::ComputeClient::NewCatletRequest.new(
            configuration: catlet_config_hash
          )

          operation = client([SCOPES[:CATLETS_WRITE]]).catlets.catlets_create({ new_catlet_request: request_obj })

          raise 'Failed to create catlet: No operation returned' unless operation&.id

          @logger.info("Operation ID: #{operation.id} - Creating catlet...")
          result = wait_for_operation(operation.id)

          if result.completed?
            # Use OperationResult's catlet accessor
            catlet = result.catlet
            raise "Operation ID: #{operation.id} - Catlet creation completed but catlet not found" unless catlet

            @logger.info("Operation ID: #{operation.id} - created catlet with ID: #{catlet.id}")
            result



          else
            error_msg = result.status_message || 'Operation failed'
            raise "Operation ID: #{operation.id} - Catlet creation failed: #{error_msg}"
          end
        end

        def start_catlet(catlet_id)
          @logger.info("Starting catlet: #{catlet_id}")

          operation = client([SCOPES[:CATLETS_CONTROL]]).catlets.catlets_start(catlet_id)

          raise 'Failed to start catlet: No operation returned' unless operation&.id

          wait_for_operation(operation.id)
        end

        def stop_catlet(catlet_id, stop_mode = 'graceful')
          @logger.info("Stopping catlet: #{catlet_id}")

          # Map string modes to proper enum values
          api_mode = case stop_mode.to_s.downcase
                     when 'graceful', 'shutdown'
                       ::Eryph::ComputeClient::CatletStopMode::SHUTDOWN
                     when 'hard'
                       ::Eryph::ComputeClient::CatletStopMode::HARD
                     when 'kill'
                       ::Eryph::ComputeClient::CatletStopMode::KILL
                     else
                       ::Eryph::ComputeClient::CatletStopMode::SHUTDOWN
                     end

          # Create proper StopCatletRequestBody object
          stop_request = ::Eryph::ComputeClient::StopCatletRequestBody.new(
            mode: api_mode
          )
          operation = client([SCOPES[:CATLETS_CONTROL]]).catlets.catlets_stop(catlet_id, stop_request)

          raise 'Failed to stop catlet: No operation returned' unless operation&.id

          wait_for_operation(operation.id)
        end

        def destroy_catlet(catlet_id)
          @logger.info("Destroying catlet: #{catlet_id}")

          operation = client([SCOPES[:CATLETS_WRITE]]).catlets.catlets_delete(catlet_id)

          raise 'Failed to destroy catlet: No operation returned' unless operation&.id

          wait_for_operation(operation.id)
        end

        def list_projects
          response = client([SCOPES[:PROJECTS_READ]]).projects.projects_list
          # Handle the response structure - ProjectList has 'value' property with array
          response.respond_to?(:value) ? response.value : response
        rescue StandardError => e
          @ui.error("Failed to list projects: #{e.message}")
          []
        end

        def get_project(project_name)
          projects = list_projects
          projects.find { |p| p.name == project_name }
        rescue StandardError => e
          @ui.error("Failed to get project #{project_name}: #{e.message}")
          nil
        end

        def create_project(project_name)
          @logger.info("Creating project: #{project_name}")

          # Create proper NewProjectRequest object
          project_request = ::Eryph::ComputeClient::NewProjectRequest.new(
            name: project_name
          )

          operation = client([SCOPES[:PROJECTS_WRITE]]).projects.projects_create(new_project_request: project_request)

          raise 'Failed to create project: No operation returned' unless operation&.id

          @logger.info("Operation ID: #{operation.id} - Creating project...")
          result = wait_for_operation(operation.id)

          if result.completed?
            # Fetch the operation again with projects expanded
            final_operation = client([SCOPES[:PROJECTS_READ]]).operations.operations_get(
              result.id,
              expand: 'projects'
            )
            final_result = ::Eryph::Compute::OperationResult.new(final_operation, client([SCOPES[:PROJECTS_READ]]))

            # Now get the project from the properly expanded operation
            project = final_result.project
            raise "Operation ID: #{operation.id} - Project creation completed but project not found" unless project

            @logger.info("Operation ID: #{operation.id} - created project with ID: #{project.id}")
            project  # Return the project, not the result
          else
            error_msg = result.status_message || 'Operation failed'
            raise "Operation ID: #{operation.id} - Project creation failed: #{error_msg}"
          end
        end

        def ensure_project_exists(project_name)
          return unless project_name

          project = get_project(project_name)
          return project if project

          unless @config.auto_create_project
            raise "Project '#{project_name}' not found and auto_create_project is disabled"
          end

          @ui.info("Project '#{project_name}' not found, creating automatically...")
          create_project(project_name)  # Now returns the project directly, no race condition!
        end

        def remove_project(project_name)
          @logger.info("Removing project: #{project_name}")
          
          project = get_project(project_name)
          raise "Project '#{project_name}' not found" unless project

          operation = client([SCOPES[:PROJECTS_WRITE]]).projects.projects_delete(project.id)
          raise 'Failed to remove project: No operation returned' unless operation&.id

          @logger.info("Operation ID: #{operation.id} - Removing project...")
          result = wait_for_operation(operation.id)

          if result.completed?
            @logger.info("Operation ID: #{operation.id} - project removed successfully")
            result
          else
            error_msg = result.status_message || 'Operation failed'
            raise "Operation ID: #{operation.id} - Project removal failed: #{error_msg}"
          end
        end

        def get_network_config(project_name)
          project = get_project(project_name)
          raise "Project '#{project_name}' not found" unless project

          response = client([SCOPES[:PROJECTS_READ]]).virtual_networks.virtual_networks_get_config(project.id)
          response.respond_to?(:configuration) ? response.configuration : response
        rescue StandardError => e
          @ui.error("Failed to get network configuration for project #{project_name}: #{e.message}")
          raise e
        end

        def set_network_config(project_name, config_yaml)
          project = get_project(project_name)
          raise "Project '#{project_name}' not found" unless project

          # Parse YAML to hash (encoding should be handled by caller)
          config_hash = YAML.safe_load(config_yaml)
          
          # Create proper VirtualNetworkConfiguration object
          network_config = ::Eryph::ComputeClient::VirtualNetworkConfiguration.new(
            configuration: config_hash
          )

          operation = client([SCOPES[:PROJECTS_WRITE]]).virtual_networks.virtual_networks_set_config(
            project.id, 
            virtual_network_configuration: network_config
          )

          raise 'Failed to set network configuration: No operation returned' unless operation&.id

          @logger.info("Operation ID: #{operation.id} - Setting network configuration...")
          result = wait_for_operation(operation.id)

          if result.completed?
            @logger.info("Operation ID: #{operation.id} - network configuration set successfully")
            result
          else
            error_msg = result.status_message || 'Operation failed'
            raise "Operation ID: #{operation.id} - Network configuration failed: #{error_msg}"
          end
        rescue StandardError => e
          @ui.error("Failed to set network configuration for project #{project_name}: #{e.message}")
          raise e
        end

        def validate_catlet_config(catlet_config)
          @ui.info('Validating catlet configuration...')

          begin
            validation_result = handle_api_errors do
              client([SCOPES[:CATLETS_READ]]).validate_catlet_config(catlet_config)
            end

            if validation_result.respond_to?(:is_valid) && validation_result.is_valid
              @ui.success('Configuration validated successfully')
              true
            elsif validation_result.respond_to?(:errors) && validation_result.errors
              @ui.error('Configuration validation failed:')
              validation_result.errors.each do |error|
                @ui.error("  - #{error}")
              end
              false
            else
              @ui.detail("Validation result: #{validation_result}")
              true # Assume valid if we can't determine otherwise
            end
          rescue Errors::EryphError => e
            @ui.error("Config validation failed: #{e.friendly_message}")
            @ui.detail('Proceeding with catlet creation...')
            true # Don't block creation if validation service unavailable
          end
        end

        def wait_for_operation(operation_id, timeout = 600)
          @logger.info("Waiting for operation #{operation_id}...")
          primary_task_name = nil
          operation_started = false

          result = client([SCOPES[:CATLETS_READ]]).wait_for_operation(operation_id, timeout: timeout) do |event_type, data|
            case event_type

            when :resource_new
              resource_type = data.resource_type || 'Resource'
              resource_id = data.resource_id || data.id || 'unknown'
              @logger.debug("Attached #{resource_type} '#{resource_id}' to operation")

            when :task_new
              # Check if this is the primary task (ParentTaskId == operation_id)
              if data.respond_to?(:parent_task_id) && data.parent_task_id == operation_id
                primary_task_name = data.respond_to?(:display_name) && data.display_name ? data.display_name :
                                   (data.respond_to?(:name) && data.name ? data.name : 'Operation')

                unless operation_started
                  @ui.info("Waiting for operation #{primary_task_name} (#{operation_id})")
                  operation_started = true
                end
              end

            when :log_entry
              # Display log messages like .NET client verbose output
              if data.respond_to?(:message) && data.message
                @ui.info(data.message)
              end
            end
          end

          # Show final result
          if result.completed?
            @ui.info("Operation ID: #{operation_id} - Operation completed successfully")
            @logger.info("Operation #{operation_id} completed successfully")
          elsif result.failed?
            error_msg = result.status_message || 'Operation failed'
            @ui.info("Operation ID: #{operation_id} - Operation failed: #{error_msg}")
            @ui.error("Operation failed: #{error_msg}")
            raise "Operation #{operation_id} failed: #{error_msg}"
          else
            @ui.info("Operation ID: #{operation_id} - Operation finished with status: #{result.status}")
            @ui.warn("Operation finished with status: #{result.status}")
          end

          result
        rescue StandardError => e
          @ui.error("Error waiting for operation: #{e.message}")
          raise e
        end

        private

        def create_client(scopes = nil)
          config_name = @config.configuration_name

          # Build options for client creation
          client_options = {}

          # Add SSL configuration options
          ssl_config = {}
          ssl_config[:verify_ssl] = @config.ssl_verify unless @config.ssl_verify.nil?
          ssl_config[:ca_file] = @config.ssl_ca_file if @config.ssl_ca_file
          client_options[:ssl_config] = ssl_config if ssl_config.any?

          # Add minimal scopes - use provided scopes or default to catlets+projects write
          client_options[:scopes] = scopes || [SCOPES[:CATLETS_WRITE], SCOPES[:PROJECTS_WRITE]]

          # Add client_id if specified
          client_options[:client_id] = @config.client_id if @config.client_id

          info_msg = if config_name
                       "Connecting to eryph using configuration: #{config_name}"
                     else
                       'Connecting to eryph using automatic credential discovery'
                     end
          @logger.debug(info_msg)

          begin
            client = ::Eryph.compute_client(config_name, **client_options)
            @logger.debug('Successfully connected to eryph.')
            client
          rescue StandardError => e
            @ui.error("Failed to connect to eryph: #{e.message}")
            @ui.info('Make sure eryph is running and your credentials are configured')
            raise "Failed to connect to eryph: #{e.message}"
          end
        end

        # Enhanced error handling that converts API errors to user-friendly messages
        def handle_api_errors
          yield
        rescue StandardError => e
          if e.is_a?(::Eryph::Compute::ProblemDetailsError)
            @ui.error("API Error: #{e.friendly_message}")
            if e.has_problem_details?
              @ui.detail("Problem Type: #{e.problem_type}") if e.problem_type
              @ui.detail("Instance: #{e.instance}") if e.instance
            end
            raise Errors::EryphError.new(e.friendly_message, e)
          else
            # Re-raise other errors as-is but with better context
            @ui.error("Unexpected error: #{e.message}")
            @logger.debug("Error class: #{e.class}")
            raise e
          end
        end
      end
    end
  end
end
