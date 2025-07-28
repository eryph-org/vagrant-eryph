require 'optparse'

module VagrantPlugins
  module Eryph
    class Command < Vagrant.plugin('2', :command)
      def self.synopsis
        'manage Eryph projects and their configurations'
      end

      def initialize(argv, env)
        super
        @main_args, @sub_command, @sub_args = split_main_and_subcommand(argv)
        @subcommands = Vagrant::Registry.new
        @subcommands.register(:project) { ProjectCommand }
      end

      def execute
        if @main_args.include?('-h') || @main_args.include?('--help')
          # Print the help for all the eryph commands.
          return help
        end

        # If we reached this far then we must have a subcommand. If not,
        # then we also just print the help and exit.
        command_class = @subcommands.get(@sub_command.to_sym) if @sub_command
        return help if !command_class || !@sub_command
        @logger.debug("Invoking command class: #{command_class} #{@sub_args.inspect}")

        # Initialize and execute the command class
        command_class.new(@sub_args, @env).execute
      end

      def help
        opts = OptionParser.new do |o|
          o.banner = 'Usage: vagrant eryph <subcommand> [<args>]'
          o.separator ''
          o.separator 'Available subcommands:'

          # Add the available subcommands as separators in order to print them
          # out as well.
          keys = []
          @subcommands.each { |key, _value| keys << key.to_s }

          keys.sort.each do |key|
            o.separator "     #{key}"
          end

          o.separator ''
          o.separator 'For help on any individual subcommand run `vagrant eryph <subcommand> -h`'
        end

        @env.ui.info(opts.help, prefix: false)
      end
    end

    class ProjectCommand < Vagrant.plugin('2', :command)
      def self.synopsis
        'manage Eryph project settings'
      end

      def initialize(argv, env)
        super

        @options = {}
        @parser = OptionParser.new do |o|
          o.banner = 'Usage: vagrant eryph project <subcommand> [options]'
          o.separator ''
          o.separator 'Subcommands:'
          o.separator '     network    Configure project networks'
          o.separator '     list       List available projects'
          o.separator '     create     Create a new project'
          o.separator '     show       Show project details'
          o.separator ''
        end

        @main_args, @sub_command, @sub_args = split_main_and_subcommand(argv)
      end

      def execute
        case @sub_command
        when 'network'
          execute_network
        when 'list'
          execute_list
        when 'create'
          execute_create
        when 'show'
          execute_show
        else
          @env.ui.info(@parser.help, prefix: false)
          return 1
        end
      end

      private

      def execute_network
        parser = OptionParser.new do |o|
          o.banner = 'Usage: vagrant eryph project network <project-name> [options]'
          o.separator ''
          o.separator 'Options:'
          o.separator ''
          
          o.on('--add NETWORK', String, 'Add network to project') do |network|
            @options[:add_network] = network
          end
          
          o.on('--remove NETWORK', String, 'Remove network from project') do |network|
            @options[:remove_network] = network
          end
          
          o.on('--list', 'List project networks') do
            @options[:list_networks] = true
          end
          
          o.on('-h', '--help', 'Show this help') do
            @env.ui.info(o.help, prefix: false)
            return 0
          end
        end

        # Parse the options
        argv = parse_options(parser)
        return if !argv

        if argv.empty?
          @env.ui.error('Project name is required')
          @env.ui.info(parser.help, prefix: false)
          return 1
        end

        project_name = argv[0]

        # Get Eryph client from any provider machine or create new one
        client = get_eryph_client

        if @options[:list_networks]
          list_project_networks(client, project_name)
        elsif @options[:add_network]
          add_project_network(client, project_name, @options[:add_network])
        elsif @options[:remove_network]
          remove_project_network(client, project_name, @options[:remove_network])
        else
          @env.ui.info(parser.help, prefix: false)
          return 1
        end

        0
      end

      def execute_list
        client = get_eryph_client
        
        @env.ui.info('Available Eryph projects:', prefix: false)
        projects = client.list_projects
        
        if projects.empty?
          @env.ui.warn('No projects found')
        else
          projects.each do |project|
            @env.ui.info("  #{project.name}", prefix: false)
          end
        end

        0
      end

      def execute_create
        parser = OptionParser.new do |o|
          o.banner = 'Usage: vagrant eryph project create <project-name> [options]'
          o.separator ''
          o.separator 'Options:'
          o.separator ''
          
          o.on('--description DESC', String, 'Project description') do |desc|
            @options[:description] = desc
          end
        end

        argv = parse_options(parser)
        return if !argv

        if argv.empty?
          @env.ui.error('Project name is required')
          @env.ui.info(parser.help, prefix: false)
          return 1
        end

        project_name = argv[0]
        client = get_eryph_client

        @env.ui.info("Creating project: #{project_name}")
        
        # Create project with custom description if provided
        project_request = {
          name: project_name,
          description: @options[:description] || "Created via Vagrant Eryph plugin"
        }
        
        begin
          operation = client.client.projects.projects_create({new_project_request: project_request})
          if operation && operation.id
            @env.ui.info("Project creation initiated (Operation ID: #{operation.id})")
            client.wait_for_operation(operation.id)
            @env.ui.info("Project '#{project_name}' created successfully")
          end
        rescue => e
          @env.ui.error("Failed to create project: #{e.message}")
          return 1
        end

        0
      end

      def execute_show
        argv = parse_options
        return if !argv

        if argv.empty?
          @env.ui.error('Project name is required')
          return 1
        end

        project_name = argv[0]
        client = get_eryph_client

        begin
          project = client.get_project(project_name)
          if project
            @env.ui.info("Project: #{project.name}", prefix: false)
            @env.ui.info("Description: #{project.description || 'N/A'}", prefix: false)
            
            # Show project networks if available
            if project.respond_to?(:networks) && project.networks
              @env.ui.info("Networks:", prefix: false)
              project.networks.each do |network|
                @env.ui.info("  - #{network.name}", prefix: false)
              end
            end
          else
            @env.ui.error("Project '#{project_name}' not found")
            return 1
          end
        rescue => e
          @env.ui.error("Failed to get project: #{e.message}")
          return 1
        end

        0
      end

      def get_eryph_client
        # Try to get client from existing machines
        @env.machine_names.each do |name|
          machine = @env.machine(name, :eryph)
          if machine.provider_config.is_a?(VagrantPlugins::Eryph::Config)
            return Helpers::EryphClient.new(machine)
          end
        end

        # If no Eryph machines found, create a basic client with default config
        # This is a simplified approach - in a real implementation you might want
        # to create a temporary machine-like object with default configuration
        raise 'No Eryph provider configuration found. Please configure at least one machine with the Eryph provider.'
      end

      def list_project_networks(client, project_name)
        begin
          project = client.get_project(project_name)
          if project
            @env.ui.info("Networks for project '#{project_name}':", prefix: false)
            
            if project.respond_to?(:networks) && project.networks && project.networks.any?
              project.networks.each do |network|
                @env.ui.info("  - #{network.name}", prefix: false)
              end
            else
              @env.ui.info("  No networks configured", prefix: false)
            end
          else
            @env.ui.error("Project '#{project_name}' not found")
          end
        rescue => e
          @env.ui.error("Failed to list project networks: #{e.message}")
        end
      end

      def add_project_network(client, project_name, network_name)
        @env.ui.info("Adding network '#{network_name}' to project '#{project_name}'...")
        
        begin
          # This would need to be implemented based on the actual Eryph API
          # for updating project network configurations
          @env.ui.warn("Network configuration API not yet implemented")
          @env.ui.info("Would add network: #{network_name}")
        rescue => e
          @env.ui.error("Failed to add network: #{e.message}")
        end
      end

      def remove_project_network(client, project_name, network_name)
        @env.ui.info("Removing network '#{network_name}' from project '#{project_name}'...")
        
        begin
          # This would need to be implemented based on the actual Eryph API
          @env.ui.warn("Network configuration API not yet implemented")
          @env.ui.info("Would remove network: #{network_name}")
        rescue => e
          @env.ui.error("Failed to remove network: #{e.message}")
        end
      end
    end
  end
end