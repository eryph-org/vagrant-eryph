require 'eryph'

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
          response = client.catlets.catlets_list
          # CatletList object contains 'value' array with actual catlets
          response.respond_to?(:value) ? response.value : []
        rescue => e
          @ui.error("Failed to list catlets: #{e.message}")
          []
        end

        def get_catlet(catlet_id)
          client.catlets.catlets_get(catlet_id)
        rescue => e
          @ui.error("Failed to get catlet #{catlet_id}: #{e.message}")
          nil
        end

        def create_catlet(catlet_config_hash)
          @ui.info("Creating catlet: #{catlet_config_hash[:name]}")
          
          # Create proper NewCatletRequest object with hash configuration
          # This follows the same pattern as AWS provider - simple hash-based config
          request_obj = ::Eryph::ComputeClient::NewCatletRequest.new(
            configuration: catlet_config_hash
          )
          
          operation = client.catlets.catlets_create({new_catlet_request: request_obj})
          
          if operation && operation.id
            @ui.info("Catlet creation initiated (Operation ID: #{operation.id})")
            result = wait_for_operation(operation.id)
            
            # After successful creation, find the catlet by name
            # Note: operation resources may not return the correct ID immediately after creation
            if result.status == 'Completed'
              catlet_name = catlet_config_hash[:name]
              @ui.info("Looking for created catlet by name: #{catlet_name}")
              
              catlets = client.catlets.catlets_list
              created_catlet = catlets.value.find { |c| c.name == catlet_name }
              
              if created_catlet
                catlet_id = created_catlet.id
                @ui.info("Catlet created with ID: #{catlet_id}")
                @ui.info("Starting catlet...")
                start_catlet(catlet_id)
                
                # Return a result object that includes the catlet ID for the action
                result.define_singleton_method(:catlet_id) { catlet_id }
                result.define_singleton_method(:catlet) { created_catlet }
                return result
              else
                raise "Catlet creation completed but catlet not found with name: #{catlet_name}"
              end
            else
              raise "Catlet creation failed with status: #{result.status}"
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

        def wait_for_operation(operation_id, timeout = 600)
          @ui.info("Waiting for operation #{operation_id} to complete...")
          
          # Use the client's built-in wait_for_operation method
          begin
            operation = client.wait_for_operation(operation_id, timeout: timeout)
            
            case operation.status
            when 'Completed'
              @ui.info("Operation completed successfully")
              return operation
            when 'Failed'
              error_msg = operation.status_message || "Operation failed"
              @ui.error("Operation failed: #{error_msg}")
              raise "Operation #{operation_id} failed: #{error_msg}"
            else
              @ui.warn("Operation finished with status: #{operation.status}")
              return operation
            end
          rescue Timeout::Error => e
            @ui.error("Operation timed out: #{e.message}")
            raise e
          rescue => e
            @ui.error("Error waiting for operation: #{e.message}")
            raise e
          end
        end

        private

        def create_client
          config_name = @config.configuration_name || 'default'
          
          # Try the specified configuration first
          begin
            @ui.info("Attempting to connect using configuration: #{config_name}")
            return create_client_for_config(config_name)
          rescue => e
            @ui.warn("Failed to connect with config '#{config_name}': #{e.message}")
            
            # Only try 'zero' fallback if we were using 'default'
            if config_name == 'default'
              begin
                @ui.info("Falling back to configuration: zero")
                client = create_client_for_config('zero')
                # Check if system client was used (if detectable)
                if using_system_client?(client)
                  @ui.info("INFO: You are using the system-client which requires admin privileges.")
                  @ui.info("      Consider creating a custom client to run without admin credentials.")
                end
                return client
              rescue => zero_error
                @ui.error("Failed to connect with config 'zero': #{zero_error.message}")
                raise "Failed to connect to Eryph API. Tried configurations: default, zero"
              end
            else
              # For non-default configs, don't try fallback
              raise "Failed to connect to Eryph API with configuration: #{config_name}"
            end
          end
        end

        def create_client_for_config(config_name)
          # Build options for client creation
          client_options = {}
          
          # Add SSL verification option (note: Ruby client uses verify_ssl, not ssl_verify)
          client_options[:verify_ssl] = @config.ssl_verify if @config.ssl_verify != nil
          
          # Add other SSL options if supported
          client_options[:ssl_ca_file] = @config.ssl_ca_file if @config.ssl_ca_file
          
          # Create client with options (Ruby client expects options as keyword arguments)
          if @config.client_id
            ::Eryph.compute_client(config_name, @config.client_id, **client_options)
          else
            ::Eryph.compute_client(config_name, **client_options)
          end
        end

        def build_client_options
          options = {}
          
          # Add endpoint_name if specified
          options[:endpoint_name] = @config.endpoint_name if @config.endpoint_name
          
          # Add SSL options
          options[:ssl_verify] = @config.ssl_verify if @config.ssl_verify != nil
          options[:ssl_ca_file] = @config.ssl_ca_file if @config.ssl_ca_file
          
          # Add logger
          options[:logger] = create_logger
          
          options
        end

        def using_system_client?(client)
          # This is a placeholder - we may not be able to detect if system client is being used
          # The Ruby client handles this internally
          false
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
      end
    end
  end
end