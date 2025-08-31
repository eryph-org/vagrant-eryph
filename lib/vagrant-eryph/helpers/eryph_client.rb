require 'eryph'
require 'set'
require_relative '../errors'

module VagrantPlugins
  module Eryph
    module Helpers
      class EryphClient
        def initialize(machine)
          @machine = machine
          @config = machine.provider_config
          @ui = machine.ui
          @client = nil
        end

        def client
          return @client if @client

          @client = create_client
          @client
        end

        def list_catlets
          handle_api_errors do
            response = client.catlets.catlets_list
            # CatletList object contains 'value' array with actual catlets
            response.respond_to?(:value) ? response.value : []
          end
        rescue Errors::EryphError
          []  # Return empty array on API errors to allow graceful degradation
        end

        def get_catlet(catlet_id)
          handle_api_errors do
            client.catlets.catlets_get(catlet_id)
          end
        rescue Errors::EryphError
          nil  # Return nil on errors to allow graceful handling
        end

        def create_catlet(catlet_config_hash)
          @ui.info("Creating catlet: #{catlet_config_hash[:name]}")
          
          # Validate configuration first
          unless validate_catlet_config(catlet_config_hash)
            raise "Catlet configuration validation failed"
          end
          
          # Create proper NewCatletRequest object with hash configuration
          request_obj = ::Eryph::ComputeClient::NewCatletRequest.new(
            configuration: catlet_config_hash
          )
          
          operation = client.catlets.catlets_create({new_catlet_request: request_obj})
          
          if operation && operation.id
            @ui.info("Catlet creation initiated (Operation ID: #{operation.id})")
            result = wait_for_operation(operation.id)
            
            if result.completed?
              # Use OperationResult's catlet accessor - much simpler!
              catlet = result.catlet
              if catlet
                @ui.info("Catlet created with ID: #{catlet.id}")
                @ui.info("Starting catlet...")
                start_catlet(catlet.id)
                return result
              else
                @ui.warn("Catlet creation completed but no catlet found in operation result")
                # Fallback to name-based lookup
                catlet_name = catlet_config_hash[:name]
                @ui.info("Looking for created catlet by name: #{catlet_name}")
                
                catlets = client.catlets.catlets_list
                created_catlet = catlets.value.find { |c| c.name == catlet_name }
                
                if created_catlet
                  @ui.info("Found catlet with ID: #{created_catlet.id}")
                  start_catlet(created_catlet.id)
                  return result
                else
                  raise "Catlet creation completed but catlet not found"
                end
              end
            else
              error_msg = result.status_message || "Operation failed"
              raise "Catlet creation failed: #{error_msg}"
            end
          else
            raise "Failed to create catlet: No operation returned"
          end
        end

        def start_catlet(catlet_id)
          @ui.info("Starting catlet: #{catlet_id}")
          
          operation = client.catlets.catlets_start(catlet_id)
          
          if operation && operation.id
            @ui.info("Catlet start initiated (Operation ID: #{operation.id})")
            wait_for_operation(operation.id)
          else
            raise "Failed to start catlet: No operation returned"
          end
        end

        def stop_catlet(catlet_id, stop_mode = 'graceful')
          @ui.info("Stopping catlet: #{catlet_id}")
          
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
          operation = client.catlets.catlets_stop(catlet_id, stop_request)
          
          if operation && operation.id
            @ui.info("Catlet stop initiated (Operation ID: #{operation.id})")
            wait_for_operation(operation.id)
          else
            raise "Failed to stop catlet: No operation returned" 
          end
        end

        def destroy_catlet(catlet_id)
          @ui.info("Destroying catlet: #{catlet_id}")
          
          operation = client.catlets.catlets_delete(catlet_id)
          
          if operation && operation.id
            @ui.info("Catlet destruction initiated (Operation ID: #{operation.id})")
            wait_for_operation(operation.id)
          else
            raise "Failed to destroy catlet: No operation returned"
          end
        end

        def list_projects
          response = client.projects.projects_list
          # Handle the response structure - ProjectList has 'value' property with array
          response.respond_to?(:value) ? response.value : response
        rescue => e
          @ui.error("Failed to list projects: #{e.message}")
          []
        end

        def get_project(project_name)
          projects = list_projects
          projects.find { |p| p.name == project_name }
        rescue => e
          @ui.error("Failed to get project #{project_name}: #{e.message}")
          nil
        end

        def create_project(project_name)
          @ui.info("Creating project: #{project_name}")
          
          # Create proper NewProjectRequest object
          project_request = ::Eryph::ComputeClient::NewProjectRequest.new(
            name: project_name
          )
          
          operation = client.projects.projects_create(new_project_request: project_request)
          
          if operation && operation.id
            @ui.info("Project creation initiated (Operation ID: #{operation.id})")
            wait_for_operation(operation.id)
          else
            raise "Failed to create project: No operation returned"
          end
        end

        def ensure_project_exists(project_name)
          return unless project_name

          project = get_project(project_name)
          return project if project

          if @config.auto_create_project
            @ui.info("Project '#{project_name}' not found, creating automatically...")
            create_project(project_name)
            get_project(project_name)
          else
            raise "Project '#{project_name}' not found and auto_create_project is disabled"
          end
        end

        def validate_catlet_config(catlet_config)
          @ui.info("Validating catlet configuration...")
          
          begin
            validation_result = handle_api_errors do
              client.validate_catlet_config(catlet_config)
            end
            
            if validation_result.respond_to?(:is_valid) && validation_result.is_valid
              @ui.success("Configuration validated successfully")
              return true
            elsif validation_result.respond_to?(:errors) && validation_result.errors
              @ui.error("Configuration validation failed:")
              validation_result.errors.each do |error|
                @ui.error("  - #{error}")
              end
              return false
            else
              @ui.detail("Validation result: #{validation_result}")
              return true  # Assume valid if we can't determine otherwise
            end
          rescue Errors::EryphError => e
            @ui.warn("Config validation failed: #{e.friendly_message}")
            @ui.detail("Proceeding with catlet creation...")
            return true  # Don't block creation if validation service unavailable
          end
        end

        def wait_for_operation(operation_id, timeout = 600)
          start_time = Time.now
          last_update = Time.now
          shown_tasks = Set.new
          update_interval = 5  # Show updates every 5 seconds for long ops
          
          @ui.info("Waiting for operation #{operation_id}...")
          
          result = client.wait_for_operation(operation_id, timeout: timeout) do |event_type, data|
            case event_type
            when :task_new
              # Show new tasks
              task_name = data.name || data.id
              unless shown_tasks.include?(task_name)
                @ui.info("  → #{task_name}")
                shown_tasks.add(task_name)
              end
              
            when :task_update
              # Show task completions/failures
              task_name = data.name || data.id
              if data.status == 'Completed' && shown_tasks.include?(task_name)
                @ui.success("  ✓ #{task_name}")
              elsif data.status == 'Failed'
                error_msg = data.error_message || data.status_message || 'Task failed'
                @ui.error("  ✗ #{task_name}: #{error_msg}")
              end
              
            when :resource_new
              # Show created resources
              resource_type = data.resource_type || 'Resource'
              resource_id = data.resource_id || data.id || 'unknown'
              @ui.info("  • Created #{resource_type}: #{resource_id}")
              
            when :log_entry
              # Only show non-debug log entries
              if data.respond_to?(:level) && data.level != 'Debug'
                message = data.message || data.to_s
                @ui.detail("  [Log] #{message}")
              end
              
            when :status
              # For long operations, show periodic updates (not every poll)
              elapsed = Time.now - start_time
              if Time.now - last_update > update_interval && elapsed > 10
                @ui.info("  Still working... (#{elapsed.round}s elapsed)")
                last_update = Time.now
              end
            end
          end
          
          # Show final result
          if result.completed?
            @ui.success("Operation completed successfully")
          elsif result.failed?
            error_msg = result.status_message || "Operation failed"
            @ui.error("Operation failed: #{error_msg}")
            raise "Operation #{operation_id} failed: #{error_msg}"
          else
            @ui.warn("Operation finished with status: #{result.status}")
          end
          
          result
        rescue Timeout::Error => e
          @ui.error("Operation timed out: #{e.message}")
          raise e
        rescue => e
          @ui.error("Error waiting for operation: #{e.message}")
          raise e
        end

        private

        def create_client
          config_name = @config.configuration_name
          
          # Build options for client creation
          client_options = {}
          
          # Add SSL configuration options
          ssl_config = {}
          ssl_config[:verify_ssl] = @config.ssl_verify if @config.ssl_verify != nil
          ssl_config[:ca_file] = @config.ssl_ca_file if @config.ssl_ca_file
          client_options[:ssl_config] = ssl_config if ssl_config.any?
          
          # Add scopes - request write permissions (includes read)
          client_options[:scopes] = %w[compute:write]
          
          # Add client_id if specified
          client_options[:client_id] = @config.client_id if @config.client_id
          
          info_msg = if config_name
            "Connecting to Eryph using configuration: #{config_name}"
          else
            "Connecting to Eryph using automatic credential discovery"
          end
          @ui.info(info_msg)
          
          begin
            client = ::Eryph.compute_client(config_name, **client_options)
            @ui.detail("Successfully connected to Eryph API")
            return client
          rescue => e
            @ui.error("Failed to connect to Eryph API: #{e.message}")
            @ui.detail("Make sure Eryph is running and your credentials are configured")
            raise "Failed to connect to Eryph API: #{e.message}"
          end
        end

        def create_logger
          # Create a simple logger that forwards to Vagrant's UI
          logger = Logger.new(StringIO.new)
          logger.level = Logger::INFO
          
          # Override logger methods to forward to Vagrant UI
          def logger.info(message)
            # We could forward this to @ui but it might be too verbose
          end
          
          def logger.error(message)
            # Forward errors to UI if needed
          end
          
          logger
        end

        # Enhanced error handling that converts API errors to user-friendly messages
        def handle_api_errors
          yield
        rescue => e
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
            @ui.detail("Error class: #{e.class}") 
            raise e
          end
        end
      end
    end
  end
end