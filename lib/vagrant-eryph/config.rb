# frozen_string_literal: true

require 'yaml'

module VagrantPlugins
  module Eryph
    class Config < Vagrant.plugin('2', :config)
      # Eryph-specific configuration
      attr_accessor :project

      # Client configuration
      attr_accessor :client_id

      # SSL configuration
      attr_accessor :ssl_verify

      # Cloud-init and user setup configuration
      attr_accessor :auto_config

      # Hyper-V/VirtualBox compatible properties
      attr_reader :cpus, :memory, :maxmemory, :vmname, :hostname
      attr_reader :enable_virtualization_extensions, :enable_secure_boot

      # Eryph top-level catlet properties
      attr_reader :parent, :location, :environment, :store

      # Complex structures (arrays/hashes)
      attr_accessor :cpu_config, :memory_config, :drives, :networks
      attr_accessor :catlet_name, :config_name, :auto_create_project, :configuration_name, :ssl_ca_file, :enable_winrm,
                    :vagrant_password, :ssh_key_injection, :fodder, :network_adapters, :capabilities, :variables

      # Catlet configuration - direct hash structure
      attr_accessor :catlet

      def initialize
        @project = UNSET_VALUE
        @catlet_name = UNSET_VALUE
        @config_name = UNSET_VALUE
        @auto_create_project = UNSET_VALUE

        @client_id = UNSET_VALUE
        @configuration_name = UNSET_VALUE

        @ssl_verify = UNSET_VALUE
        @ssl_ca_file = UNSET_VALUE

        @auto_config = UNSET_VALUE
        @enable_winrm = UNSET_VALUE
        @vagrant_password = UNSET_VALUE
        @ssh_key_injection = UNSET_VALUE
        @fodder = UNSET_VALUE

        # Hyper-V/VirtualBox compatible properties
        @cpus = UNSET_VALUE
        @memory = UNSET_VALUE
        @maxmemory = UNSET_VALUE
        @vmname = UNSET_VALUE
        @hostname = UNSET_VALUE
        @enable_virtualization_extensions = UNSET_VALUE
        @enable_secure_boot = UNSET_VALUE

        # Eryph top-level properties
        @parent = UNSET_VALUE
        @location = UNSET_VALUE
        @environment = UNSET_VALUE
        @store = UNSET_VALUE

        # Complex structures
        @cpu_config = UNSET_VALUE
        @memory_config = UNSET_VALUE
        @drives = UNSET_VALUE
        @networks = UNSET_VALUE
        @network_adapters = UNSET_VALUE
        @capabilities = UNSET_VALUE
        @variables = UNSET_VALUE

        # New catlet configuration
        @catlet = UNSET_VALUE
        
        # Gene references (separate from fodder)
        @genes = UNSET_VALUE
      end

      def finalize!
        @project = 'default' if @project == UNSET_VALUE
        @catlet_name = nil if @catlet_name == UNSET_VALUE
        @config_name = nil if @config_name == UNSET_VALUE
        @auto_create_project = true if @auto_create_project == UNSET_VALUE

        @client_id = nil if @client_id == UNSET_VALUE
        @configuration_name = nil if @configuration_name == UNSET_VALUE

        # SSL defaults - disable verification for localhost
        @ssl_verify = determine_ssl_verify_default if @ssl_verify == UNSET_VALUE
        @ssl_ca_file = nil if @ssl_ca_file == UNSET_VALUE

        @auto_config = true if @auto_config == UNSET_VALUE
        @enable_winrm = true if @enable_winrm == UNSET_VALUE
        # Set auto password - will be resolved based on OS when machine context is available
        @vagrant_password = :auto if @vagrant_password == UNSET_VALUE
        @ssh_key_injection = :direct if @ssh_key_injection == UNSET_VALUE
        @fodder = [] if @fodder == UNSET_VALUE
        @genes = [] if @genes == UNSET_VALUE

        # Hyper-V/VirtualBox compatible property defaults
        @cpus = nil if @cpus == UNSET_VALUE
        @memory = nil if @memory == UNSET_VALUE
        @maxmemory = nil if @maxmemory == UNSET_VALUE
        @vmname = nil if @vmname == UNSET_VALUE
        @hostname = nil if @hostname == UNSET_VALUE
        @enable_virtualization_extensions = nil if @enable_virtualization_extensions == UNSET_VALUE
        @enable_secure_boot = nil if @enable_secure_boot == UNSET_VALUE

        # Eryph property defaults
        @parent = nil if @parent == UNSET_VALUE
        @location = nil if @location == UNSET_VALUE
        @environment = nil if @environment == UNSET_VALUE
        @store = nil if @store == UNSET_VALUE

        # Complex structure defaults
        @cpu_config = nil if @cpu_config == UNSET_VALUE
        @memory_config = nil if @memory_config == UNSET_VALUE
        @drives = [] if @drives == UNSET_VALUE
        @networks = [] if @networks == UNSET_VALUE
        @network_adapters = [] if @network_adapters == UNSET_VALUE
        @capabilities = [] if @capabilities == UNSET_VALUE
        @variables = [] if @variables == UNSET_VALUE

        # Initialize catlet configuration as empty hash if not set
        @catlet = {} if @catlet == UNSET_VALUE
      end

      def validate(_machine)
        errors = _detected_errors

        # Validate required fields - check both catlet hash
        catlet_hash = @catlet.is_a?(Hash) ? @catlet : {}
        parent = catlet_hash[:parent] || catlet_hash['parent']
        errors << 'parent is required (set in catlet hash)' unless parent

        # Project is optional - defaults to 'default' if not specified
        # No validation needed since we have a fallback

        # Validate ssh_key_injection option
        if @ssh_key_injection && !%i[direct variable].include?(@ssh_key_injection)
          errors << 'ssh_key_injection must be :direct or :variable'
        end


        { 'Eryph Provider' => errors }
      end

      # Helper method to determine SSL verification default
      def determine_ssl_verify_default
        # Default to false for localhost/development, true for remote endpoints
        # This will be refined when we implement the client lookup logic
        false
      end

      # Helper method to get the effective catlet name
      def effective_catlet_name(machine)
        @catlet_name || machine.config.vm.hostname || machine.name.to_s
      end

      # Helper method to build the effective catlet configuration
      # Combines the new catlet hash with legacy individual properties for backward compatibility
      def effective_catlet_configuration(machine)
        # Start with the catlet hash configuration
        config = @catlet.dup

        # Add name and project (always required)
        config[:name] = effective_catlet_name(machine)
        config[:project] = @project

        config
      end

      # Helper method to merge user fodder with auto-generated fodder
      def merged_fodder(auto_generated_fodder = [])
        return @fodder unless @auto_config

        merged = auto_generated_fodder.dup

        # Add gene fodder (convert from gene references), deduplicating by source
        if @genes && @genes.any?
          @genes.each do |gene_config|
            # Skip duplicates based on source
            unless merged.any? { |item| item[:source] == gene_config[:source] }
              merged << gene_config
            end
          end
        end

        # Add user-provided fodder, avoiding duplicates using composite keys
        @fodder.each do |user_item|
          # Build unique key based on source/name combination
          user_key = if user_item[:source] && user_item[:name]
                      "#{user_item[:source]}:#{user_item[:name]}" # source + name
                     elsif user_item[:source]
                      user_item[:source] # source only
                     else
                      user_item[:name] # name only (local fodder)
                     end
          
          # Find existing item with same key
          existing_index = merged.find_index do |item|
            existing_key = if item[:source] && item[:name]
                            "#{item[:source]}:#{item[:name]}"
                           elsif item[:source]
                            item[:source]
                           else
                            item[:name]
                           end
            existing_key == user_key
          end
          
          if existing_index
            # Replace existing item with user-provided one
            merged[existing_index] = user_item
          else
            # Add new user item
            merged << user_item
          end
        end

        merged
      end

      # ============================================================
      # HYPER-V/VIRTUALBOX COMPATIBLE PROPERTY SETTERS
      # ============================================================

      private

      def ensure_catlet_hash!
        @catlet = {} if @catlet == UNSET_VALUE || !@catlet.is_a?(Hash)
      end

      public

      # CPU configuration
      def cpus=(value)
        @cpus = value
        @catlet = {} if @catlet == UNSET_VALUE || !@catlet.is_a?(Hash)
        @catlet[:cpu] ||= {}
        @catlet[:cpu][:count] = value
      end

      # Memory configuration (startup memory)
      def memory=(value)
        @memory = value
        @catlet = {} if @catlet == UNSET_VALUE || !@catlet.is_a?(Hash)
        @catlet[:memory] ||= {}
        @catlet[:memory][:startup] = value
      end

      # Maximum memory (enables dynamic memory)
      def maxmemory=(value)
        @maxmemory = value
        ensure_catlet_hash!
        @catlet[:memory] ||= {}
        @catlet[:memory][:maximum] = value

        # Auto-enable dynamic memory when maxmemory is set
        @catlet[:capabilities] ||= []
        @catlet[:capabilities].reject! { |c| c[:name] == 'dynamic_memory' }
        @catlet[:capabilities] << { name: 'dynamic_memory' }
      end

      # VM name (maps to catlet name)
      def vmname=(value)
        @vmname = value
        @catlet_name = value # For backward compatibility
        ensure_catlet_hash!
        @catlet[:name] = value
      end

      # Network hostname
      def hostname=(value)
        @hostname = value
        ensure_catlet_hash!
        @catlet[:hostname] = value
      end

      # Nested virtualization support
      def enable_virtualization_extensions=(value)
        @enable_virtualization_extensions = value
        ensure_catlet_hash!
        @catlet[:capabilities] ||= []
        @catlet[:capabilities].reject! { |c| c[:name] == 'nested_virtualization' }

        return unless value

        @catlet[:capabilities] << { name: 'nested_virtualization' }
      end

      # Secure boot support
      def enable_secure_boot=(value)
        @enable_secure_boot = value
        ensure_catlet_hash!
        @catlet[:capabilities] ||= []
        @catlet[:capabilities].reject! { |c| c[:name] == 'secure_boot' }

        return unless value

        @catlet[:capabilities] << { name: 'secure_boot' }
      end

      # ============================================================
      # ERYPH TOP-LEVEL PROPERTY SETTERS
      # ============================================================

      def parent=(value)
        @parent = value
        ensure_catlet_hash!
        @catlet[:parent] = value
      end

      def location=(value)
        @location = value
        ensure_catlet_hash!
        @catlet[:location] = value
      end

      def environment=(value)
        @environment = value
        ensure_catlet_hash!
        @catlet[:environment] = value
      end

      def store=(value)
        @store = value
        ensure_catlet_hash!
        @catlet[:store] = value
      end

      # ============================================================
      # DRIVE MANAGEMENT WITH UNIX NAMING
      # ============================================================

      DRIVE_TYPE_MAP = {
        vhd: 'VHD',
        shared_vhd: 'SharedVHD',
        dvd: 'DVD',
        vhd_set: 'VHDSet'
      }.freeze

      def add_drive(name, size: nil, type: :vhd, source: nil, **options)
        drive_config = { name: name }
        drive_config[:size] = size if size

        # Convert symbol to proper API string
        drive_config[:type] = DRIVE_TYPE_MAP[type] || type.to_s
        drive_config[:source] = source if source
        drive_config.merge!(options)

        @drives = [] if @drives == UNSET_VALUE
        @drives << drive_config

        ensure_catlet_hash!
        @catlet[:drives] ||= []
        @catlet[:drives] << drive_config
      end

      # ============================================================
      # CAPABILITIES MANAGEMENT
      # ============================================================

      def enable_capability(name, details: nil)
        ensure_catlet_hash!
        @catlet[:capabilities] ||= []
        @catlet[:capabilities].reject! { |c| c[:name] == name.to_s }
        cap_config = { name: name.to_s }
        cap_config[:details] = details if details
        @catlet[:capabilities] << cap_config
      end

      def disable_capability(name)
        ensure_catlet_hash!
        @catlet[:capabilities] ||= []
        @catlet[:capabilities].reject! { |c| c[:name] == name.to_s }
      end

      # ============================================================
      # GENE MANAGEMENT
      # ============================================================

      def add_fodder_gene(geneset, gene, fodder_name: nil, variables: nil, **options)
        # Build proper gene fodder reference syntax: gene:geneset:gene
        gene_source = "gene:#{geneset}:#{gene}"

        # Create fodder item with gene source
        fodder_config = {
          source: gene_source 
        }
        
        # Add name only if provided
        fodder_config[:name] = fodder_name if fodder_name

        # Add variables if specified - must be an array of variable objects per spec
        fodder_config[:variables] = variables if variables&.any?

        # Add any other options
        fodder_config.merge!(options) if options.any?

        # Add to genes array for later processing
        @genes = [] if @genes == UNSET_VALUE
        @genes << fodder_config

        fodder_config
        
      end

      # ============================================================
      # FODDER HELPERS
      # ============================================================

      def cloud_config(name, content = nil)
        @fodder ||= []

        if block_given?
          # DSL-style configuration
          config_data = {}
          yield config_data
          content = config_data
        end

        @fodder << {
          name: name,
          type: 'cloud-config',
          content: content
        }
      end

      def shell_script(name, content)
        @fodder ||= []
        @fodder << {
          name: name,
          type: 'shellscript',
          content: content
        }
      end

      # Helper method to extract Vagrant cloud-init configuration
      # NOTE: We don't use Vagrant's cloud-init system - we generate our own fodder
      def extract_vagrant_cloud_init_config(_machine)
        # Always return empty - we handle cloud-init through our own fodder system
        []
      end

      private

      # Convert Vagrant cloud-init configuration to Eryph fodder format
      def convert_cloud_init_to_fodder(cloud_init_config, index = 0)
        return nil unless cloud_init_config
        return nil unless cloud_init_config.content_type
        return nil if cloud_init_config.content_type == UNSET_VALUE

        # Map Vagrant content types to Eryph fodder types
        fodder_type = map_content_type_to_fodder_type(cloud_init_config.content_type)
        return nil unless fodder_type

        # Generate name based on type and index
        name = "vagrant-cloud-init-#{fodder_type}"
        name += "-#{index}" if index.positive?

        # Extract content
        content = extract_cloud_init_content(cloud_init_config)
        return nil unless content

        {
          name: name,
          type: fodder_type,
          content: content
        }
      end

      # Map Vagrant content types to Eryph fodder types
      def map_content_type_to_fodder_type(content_type)
        case content_type
        when 'text/cloud-config'
          'cloud-config'
        when 'text/x-shellscript'
          'shellscript'
        when 'text/cloud-boothook'
          'cloud-boothook'
        when 'text/cloud-config-archive'
          'cloud-config-archive'
        when 'text/part-handler'
          'part-handler'
        when 'text/upstart-job'
          'upstart-job'
        else
          nil # Unsupported content type
        end
      end

      # Extract content from cloud-init configuration
      def extract_cloud_init_content(cloud_init_config)
        inline_content = cloud_init_config.inline
        path_content = cloud_init_config.path

        # Skip UNSET_VALUE properties
        return nil if inline_content == UNSET_VALUE && path_content == UNSET_VALUE

        if inline_content && inline_content != UNSET_VALUE
          process_cloud_init_content(inline_content, cloud_init_config.content_type)
        elsif path_content && path_content != UNSET_VALUE && File.exist?(path_content)
          content = File.read(path_content)
          process_cloud_init_content(content, cloud_init_config.content_type)
        end
      end

      # Process cloud-init content based on content type
      def process_cloud_init_content(content, content_type)
        case content_type
        when 'text/cloud-config'
          # Parse YAML content into hash for cloud-config
          begin
            YAML.safe_load(content)
          rescue StandardError
            # If YAML parsing fails, return as string
            content
          end
        else
          # Return other content types as strings
          content
        end
      end
    end
  end
end
