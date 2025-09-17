# frozen_string_literal: true

require 'optparse'
require 'yaml'
require 'json'
require_relative 'config'
require_relative 'helpers/eryph_client'

module VagrantPlugins
  module Eryph
    class Command < Vagrant.plugin('2', :command)
      def self.synopsis
        'manage Eryph projects and network configurations'
      end

      def initialize(argv, env)
        super
        @main_args, @sub_command, @sub_args = split_main_and_subcommand(argv)
        @subcommands = Vagrant::Registry.new
        @subcommands.register(:project) { ProjectCommand }
        @subcommands.register(:network) { NetworkCommand }
      end

      def execute
        if @main_args.include?('-h') || @main_args.include?('--help')
          return help
        end

        command_class = @subcommands.get(@sub_command.to_sym) if @sub_command
        return help if !command_class || !@sub_command

        @logger.debug("Invoking command class: #{command_class} #{@sub_args.inspect}")
        command_class.new(@sub_args, @env).execute
      end

      def help
        opts = OptionParser.new do |o|
          o.banner = 'Usage: vagrant eryph <subcommand> [<args>]'
          o.separator ''
          o.separator 'Available subcommands:'
          o.separator '     project    Manage Eryph projects'
          o.separator '     network    Manage project network configurations'
          o.separator ''
          o.separator 'For help on any individual subcommand run `vagrant eryph <subcommand> -h`'
        end

        @env.ui.info(opts.help, prefix: false)
      end
    end

    class ProjectCommand < Vagrant.plugin('2', :command)
      def self.synopsis
        'manage Eryph projects'
      end

      def initialize(argv, env)
        super
        @options = {}
        @parser = OptionParser.new do |o|
          o.banner = 'Usage: vagrant eryph project <subcommand> [options]'
          o.separator ''
          o.separator 'Subcommands:'
          o.separator '     list       List available projects'
          o.separator '     create     Create a new project'
          o.separator '     remove     Remove a project'
          o.separator ''
          o.separator 'Global Options:'
          
          o.on('--configuration-name NAME', String, 'Eryph configuration name (default: auto-detect)') do |name|
            @options[:configuration_name] = name
          end
          
          o.on('--client-id ID', String, 'Eryph client ID') do |id|
            @options[:client_id] = id
          end

          o.on('--[no-]ssl-verify', 'Enable/disable SSL certificate verification') do |verify|
            @options[:ssl_verify] = verify
          end

          o.on('--ssl-ca-file FILE', String, 'Path to custom CA certificate file') do |file|
            @options[:ssl_ca_file] = file
          end

          o.separator ''
        end

        @main_args, @sub_command, @sub_args = split_main_and_subcommand(argv)
      end

      def execute
        case @sub_command
        when 'list'
          execute_list
        when 'create'
          execute_create
        when 'remove'
          execute_remove
        else
          @env.ui.info(@parser.help, prefix: false)
          1
        end
      end

      private

      def execute_list
        client = get_eryph_client
        @env.ui.info('Available Eryph projects:', prefix: false)
        
        projects = client.list_projects
        if projects.empty?
          @env.ui.warn('No projects found')
        else
          projects.each do |project|
            @env.ui.info("  #{project.name} (ID: #{project.id})", prefix: false)
          end
        end
        0
      end

      def execute_create
        parser = OptionParser.new do |o|
          o.banner = 'Usage: vagrant eryph project create <project-name> [options]'
          o.separator ''
          o.separator 'Options:'
          o.on('--no-wait', 'Do not wait for operation to complete') do
            @options[:no_wait] = true
          end
        end

        begin
          argv = parser.parse!(@sub_args.dup)
        rescue OptionParser::InvalidOption, OptionParser::InvalidArgument => e
          @env.ui.error("#{e.message}")
          @env.ui.info(parser.help, prefix: false)
          return nil
        end

        if argv.empty?
          @env.ui.error('Project name is required')
          @env.ui.info(parser.help, prefix: false)
          return 1
        end

        project_name = argv[0]
        client = get_eryph_client

        begin
          @env.ui.info("Creating project: #{project_name}")
          project = client.create_project(project_name)
          @env.ui.info("Project '#{project.name}' created successfully (ID: #{project.id})")
          0
        rescue StandardError => e
          @env.ui.error("Failed to create project: #{e.message}")
          1
        end
      end

      def execute_remove
        parser = OptionParser.new do |o|
          o.banner = 'Usage: vagrant eryph project remove <project-name> [options]'
          o.separator ''
          o.separator 'Options:'
          o.on('--force', 'Do not ask for confirmation') do
            @options[:force] = true
          end
          o.on('--no-wait', 'Do not wait for operation to complete') do
            @options[:no_wait] = true
          end
        end

        begin
          argv = parser.parse!(@sub_args.dup)
        rescue OptionParser::InvalidOption, OptionParser::InvalidArgument => e
          @env.ui.error("#{e.message}")
          @env.ui.info(parser.help, prefix: false)
          return nil
        end

        if argv.empty?
          @env.ui.error('Project name is required')
          @env.ui.info(parser.help, prefix: false)
          return 1
        end

        project_name = argv[0]
        client = get_eryph_client

        begin
          project = client.get_project(project_name)
          unless project
            @env.ui.error("Project '#{project_name}' not found")
            return 1
          end

          unless @options[:force]
            response = @env.ui.ask("Project '#{project.name}' (ID: #{project.id}) and all catlets will be deleted! Continue? (y/N)")
            return 0 unless response.downcase.start_with?('y')
          end

          @env.ui.info("Removing project: #{project.name}")
          delete_project(client, project.id)
          @env.ui.info("Project '#{project.name}' removed successfully")
          0
        rescue StandardError => e
          @env.ui.error("Failed to remove project: #{e.message}")
          1
        end
      end

      def get_eryph_client
        # Always use standalone client for project management commands
        create_standalone_client
      end

      private


      def create_standalone_client
        # Create a minimal machine-like object for standalone client
        require 'ostruct'
        
        config = VagrantPlugins::Eryph::Config.new
        config.configuration_name = @options[:configuration_name] if @options[:configuration_name]
        config.client_id = @options[:client_id] if @options[:client_id]
        config.ssl_verify = @options[:ssl_verify] unless @options[:ssl_verify].nil?
        config.ssl_ca_file = @options[:ssl_ca_file] if @options[:ssl_ca_file]
        config.finalize!
        
        # Create a fake machine with just the provider config we need
        fake_machine = OpenStruct.new(
          provider_config: config,
          ui: @env.ui
        )
        
        Helpers::EryphClient.new(fake_machine)
      rescue StandardError => e
        raise "Failed to create Eryph client: #{e.message}. Please ensure eryph is running and your client configuration is set up correctly."
      end

      def delete_project(client, project_id)
        operation = client.client.projects.projects_delete(project_id)
        raise 'Failed to delete project: No operation returned' unless operation&.id

        result = client.wait_for_operation(operation.id)
        unless result.completed?
          error_msg = result.status_message || 'Operation failed'
          raise "Project deletion failed: #{error_msg}"
        end
      end
    end

    class NetworkCommand < Vagrant.plugin('2', :command)
      def self.synopsis
        'manage project network configurations'
      end

      def initialize(argv, env)
        super
        @options = {}
        @parser = OptionParser.new do |o|
          o.banner = 'Usage: vagrant eryph network <subcommand> [options]'
          o.separator ''
          o.separator 'Subcommands:'
          o.separator '     get        Get project network configuration (YAML)'
          o.separator '     set        Set project network configuration from YAML'
          o.separator ''
          o.separator 'Global Options:'
          
          o.on('--configuration-name NAME', String, 'Eryph configuration name (default: auto-detect)') do |name|
            @options[:configuration_name] = name
          end
          
          o.on('--client-id ID', String, 'Eryph client ID') do |id|
            @options[:client_id] = id
          end

          o.on('--[no-]ssl-verify', 'Enable/disable SSL certificate verification') do |verify|
            @options[:ssl_verify] = verify
          end

          o.on('--ssl-ca-file FILE', String, 'Path to custom CA certificate file') do |file|
            @options[:ssl_ca_file] = file
          end

          o.separator ''
        end

        @main_args, @sub_command, @sub_args = split_main_and_subcommand(argv)
      end

      def execute
        case @sub_command
        when 'get'
          execute_get
        when 'set'
          execute_set
        else
          @env.ui.info(@parser.help, prefix: false)
          1
        end
      end

      private

      def execute_get
        parser = OptionParser.new do |o|
          o.banner = 'Usage: vagrant eryph network get <project-name> [options]'
          o.separator ''
          o.separator 'Options:'
          o.on('-o', '--output FILE', 'Write configuration to file') do |file|
            @options[:output] = file
          end
        end

        begin
          argv = parser.parse!(@sub_args.dup)
        rescue OptionParser::InvalidOption, OptionParser::InvalidArgument => e
          @env.ui.error("#{e.message}")
          @env.ui.info(parser.help, prefix: false)
          return nil
        end

        if argv.empty?
          @env.ui.error('Project name is required')
          @env.ui.info(parser.help, prefix: false)
          return 1
        end

        project_name = argv[0]
        client = get_eryph_client

        begin
          project = client.get_project(project_name)
          unless project
            @env.ui.error("Project '#{project_name}' not found")
            return 1
          end

          config_response = client.client.virtual_networks.virtual_networks_get_config(project.id)
          
          if config_response&.configuration
            # Configuration is already a Hash/Object, convert symbols to strings for clean YAML
            clean_config = deep_stringify_keys(config_response.configuration)
            yaml_config = clean_config.to_yaml

            if @options[:output]
              File.write(@options[:output], yaml_config)
              @env.ui.info("Network configuration written to: #{@options[:output]}")
            else
              @env.ui.info("Network configuration for project '#{project.name}':", prefix: false)
              @env.ui.info(yaml_config, prefix: false)
            end
          else
            @env.ui.info("No network configuration found for project '#{project.name}'")
          end
          0
        rescue StandardError => e
          @env.ui.error("Failed to get network configuration: #{e.message}")
          1
        end
      end

      def execute_set
        parser = OptionParser.new do |o|
          o.banner = 'Usage: vagrant eryph network set <project-name> [options]'
          o.separator ''
          o.separator 'Options:'
          o.on('-f', '--file FILE', 'Read configuration from file') do |file|
            @options[:file] = file
          end
          o.on('-c', '--config CONFIG', 'Configuration as string') do |config|
            @options[:config] = config
          end
          o.on('--force', 'Force import even if project names differ') do
            @options[:force] = true
          end
          o.on('--no-wait', 'Do not wait for operation to complete') do
            @options[:no_wait] = true
          end
        end

        begin
          argv = parser.parse!(@sub_args.dup)
        rescue OptionParser::InvalidOption, OptionParser::InvalidArgument => e
          @env.ui.error("#{e.message}")
          @env.ui.info(parser.help, prefix: false)
          return nil
        end

        if argv.empty?
          @env.ui.error('Project name is required')
          @env.ui.info(parser.help, prefix: false)
          return 1
        end

        unless @options[:file] || @options[:config]
          @env.ui.error('Either --file or --config is required')
          @env.ui.info(parser.help, prefix: false)
          return 1
        end

        project_name = argv[0]
        client = get_eryph_client

        begin
          project = client.get_project(project_name)
          unless project
            @env.ui.error("Project '#{project_name}' not found")
            return 1
          end

          # Read configuration
          config_content = if @options[:file]
                            unless File.exist?(@options[:file])
                              @env.ui.error("File not found: #{@options[:file]}")
                              return 1
                            end
                            File.read(@options[:file])
                          else
                            @options[:config]
                          end

          # Parse configuration
          config_data = parse_network_config(config_content)
          unless config_data
            @env.ui.error('Invalid configuration format. Expected YAML or JSON.')
            return 1
          end

          # Validate project name in config
          if config_data['project'] && config_data['project'] != project_name
            unless @options[:force]
              response = @env.ui.ask("Configuration was exported from project '#{config_data['project']}' but will be imported to '#{project_name}'. Continue? (y/N)")
              return 0 unless response.downcase.start_with?('y')
            end
          end

          # Set project name in config
          config_data['project'] = project_name

          @env.ui.info("Setting network configuration for project '#{project.name}'...")
          
          # Create request body - API expects Hash object directly
          request_body = ::Eryph::ComputeClient::UpdateProjectNetworksRequestBody.new(
            configuration: config_data
          )

          operation = client.client.virtual_networks.virtual_networks_update_config(
            project.id, 
            request_body
          )

          raise 'Failed to update network configuration: No operation returned' unless operation&.id

          unless @options[:no_wait]
            result = client.wait_for_operation(operation.id)
            unless result.completed?
              error_msg = result.status_message || 'Operation failed'
              raise "Network configuration update failed: #{error_msg}"
            end
          end

          @env.ui.info("Network configuration updated successfully for project '#{project.name}'")
          0
        rescue StandardError => e
          @env.ui.error("Failed to set network configuration: #{e.message}")
          1
        end
      end

      def get_eryph_client
        # Always use standalone client for project management commands
        create_standalone_client
      end

      private


      def create_standalone_client
        # Create a minimal machine-like object for standalone client
        require 'ostruct'
        
        config = VagrantPlugins::Eryph::Config.new
        config.configuration_name = @options[:configuration_name] if @options[:configuration_name]
        config.client_id = @options[:client_id] if @options[:client_id]
        config.ssl_verify = @options[:ssl_verify] unless @options[:ssl_verify].nil?
        config.ssl_ca_file = @options[:ssl_ca_file] if @options[:ssl_ca_file]
        config.finalize!
        
        # Create a fake machine with just the provider config we need
        fake_machine = OpenStruct.new(
          provider_config: config,
          ui: @env.ui
        )
        
        Helpers::EryphClient.new(fake_machine)
      rescue StandardError => e
        raise "Failed to create Eryph client: #{e.message}. Please ensure eryph is running and your client configuration is set up correctly."
      end

      def parse_network_config(config_string)
        # Handle encoding issues first
        # Detect UTF-16LE content (null bytes between characters)
        if config_string.include?("\u0000")
          # This is UTF-16LE content read as UTF-8, convert it properly
          clean_config = config_string.force_encoding('UTF-16LE').encode('UTF-8')
        else
          clean_config = config_string
        end
        
        clean_config = clean_config.strip
        clean_config = clean_config.gsub(/\r\n/, "\n")

        # Try JSON first
        if clean_config.start_with?('{') && clean_config.end_with?('}')
          begin
            return JSON.parse(clean_config)
          rescue JSON::ParserError
            return nil
          end
        end

        # Try YAML
        begin
          return YAML.safe_load(clean_config)
        rescue Psych::SyntaxError
          return nil
        end
      end

      def deep_stringify_keys(obj)
        case obj
        when Hash
          obj.each_with_object({}) do |(key, value), result|
            result[key.to_s] = deep_stringify_keys(value)
          end
        when Array
          obj.map { |item| deep_stringify_keys(item) }
        else
          obj
        end
      end
    end
  end
end