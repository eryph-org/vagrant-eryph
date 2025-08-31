require 'yaml'

module VagrantPlugins
  module Eryph
    class Config < Vagrant.plugin('2', :config)
      # Eryph-specific configuration
      attr_accessor :project
      attr_accessor :catlet_name
      attr_accessor :config_name
      attr_accessor :auto_create_project
      
      # Client configuration
      attr_accessor :client_id
      attr_accessor :configuration_name
      
      # SSL configuration
      attr_accessor :ssl_verify
      attr_accessor :ssl_ca_file
      
      # Cloud-init and user setup configuration
      attr_accessor :auto_config
      attr_accessor :enable_winrm
      attr_accessor :vagrant_password
      attr_accessor :ssh_key_injection
      attr_accessor :fodder
      
      # Hyper-V/VirtualBox compatible properties
      attr_reader :cpus, :memory, :maxmemory, :vmname, :hostname
      attr_reader :enable_virtualization_extensions, :enable_secure_boot
      
      # Eryph top-level catlet properties  
      attr_reader :parent, :location, :environment, :store
      
      # Complex structures (arrays/hashes)
      attr_accessor :cpu_config, :memory_config, :drives, :networks
      attr_accessor :network_adapters, :capabilities, :variables
      
      # Catlet configuration - direct hash structure
      attr_accessor :catlet
      
      # Legacy support for backward compatibility (will be deprecated)
      attr_accessor :parent_gene
      attr_accessor :cpu
      
      def initialize
        @project = UNSET_VALUE
        @parent_gene = UNSET_VALUE
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
        
        # Legacy configuration (for backward compatibility)
        @cpu = UNSET_VALUE
      end

      def finalize!
        @project = 'default' if @project == UNSET_VALUE
        @parent_gene = 'dbosoft/ubuntu:22.04' if @parent_gene == UNSET_VALUE
        @catlet_name = nil if @catlet_name == UNSET_VALUE
        @config_name = nil if @config_name == UNSET_VALUE
        @auto_create_project = true if @auto_create_project == UNSET_VALUE
        
        @client_id = nil if @client_id == UNSET_VALUE
        @configuration_name = nil if @configuration_name == UNSET_VALUE
        
        # SSL defaults - disable verification for localhost
        @ssl_verify = self.determine_ssl_verify_default if @ssl_verify == UNSET_VALUE
        @ssl_ca_file = nil if @ssl_ca_file == UNSET_VALUE
        
        @auto_config = true if @auto_config == UNSET_VALUE
        @enable_winrm = true if @enable_winrm == UNSET_VALUE
        @vagrant_password = 'vagrant' if @vagrant_password == UNSET_VALUE
        @ssh_key_injection = :direct if @ssh_key_injection == UNSET_VALUE
        @fodder = [] if @fodder == UNSET_VALUE
        
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
        
        # Legacy configuration defaults (for backward compatibility)
        @cpu = nil if @cpu == UNSET_VALUE
      end

      def validate(machine)
        errors = _detected_errors

        # Validate required fields - check both catlet hash and legacy parent_gene
        catlet_hash = @catlet.is_a?(Hash) ? @catlet : {}
        parent = (catlet_hash.dig(:parent) || catlet_hash.dig('parent')) || @parent_gene
        errors << 'parent is required (set in catlet hash or parent_gene)' if !parent
        
        # Project is optional - defaults to 'default' if not specified
        # No validation needed since we have a fallback

        # Validate ssh_key_injection option
        if @ssh_key_injection && ![:direct, :variable].include?(@ssh_key_injection)
          errors << 'ssh_key_injection must be :direct or :variable'
        end

        # Validate fodder structure if provided
        if @fodder && !@fodder.is_a?(Array)
          errors << 'fodder must be an array'
        elsif @fodder
          @fodder.each_with_index do |item, index|
            unless item.is_a?(Hash)
              errors << "fodder[#{index}] must be a hash"
              next
            end
            
            unless item[:name] && item[:type] && item[:content]
              errors << "fodder[#{index}] must have :name, :type, and :content keys"
            end
            
            unless ['cloud-config', 'cloud-boothook', 'cloud-config-archive', 'shellscript'].include?(item[:type])
              errors << "fodder[#{index}] type must be one of: cloud-config, cloud-boothook, cloud-config-archive, shellscript"
            end
          end
        end

        # Validate numeric values
        if @cpu && (!@cpu.is_a?(Integer) || @cpu <= 0)
          errors << 'cpu must be a positive integer'
        end

        if @memory && (!@memory.is_a?(Integer) || @memory <= 0)
          errors << 'memory must be a positive integer (MB)'
        end


        { 'Eryph Provider' => errors }
      end

      # Helper method to determine if this is likely a Windows catlet
      # This is deprecated - use Vagrant's config.vm.guest instead
      def windows_catlet?
        # For backward compatibility, keep the gene name heuristic
        # But in practice, the plugin should rely on config.vm.guest
        parent = (@catlet&.dig(:parent) || @catlet&.dig('parent')) || @parent_gene
        return false unless parent
        
        # Simple heuristic based on parent gene name
        gene_name = parent.downcase
        gene_name.include?('windows') || gene_name.include?('win-') || gene_name.include?('winsrv')
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
        
        # Legacy backward compatibility - merge individual properties if catlet hash doesn't have them
        # Only apply legacy values if the catlet hash doesn't already specify them
        config[:parent] = @parent_gene if config[:parent].nil? && @parent_gene
        config[:cpu] = @cpu if config[:cpu].nil? && @cpu
        config[:memory] = @memory if config[:memory].nil? && @memory
        config[:drives] = @drives if config[:drives].nil? && @drives && @drives.any?
        config[:networks] = @networks if config[:networks].nil? && @networks && @networks.any?
        
        config
      end

      # Helper method to merge user fodder with auto-generated fodder
      def merged_fodder(auto_generated_fodder = [])
        return @fodder unless @auto_config
        
        merged = auto_generated_fodder.dup
        
        # Add user-provided fodder, avoiding duplicates by name
        @fodder.each do |user_item|
          existing_index = merged.find_index { |item| item[:name] == user_item[:name] }
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
        @catlet[:capabilities].reject! { |c| c[:name] == "dynamic_memory" }
        @catlet[:capabilities] << { name: "dynamic_memory" }
      end
      
      # VM name (maps to catlet name)
      def vmname=(value)
        @vmname = value
        @catlet_name = value  # For backward compatibility
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
        @catlet[:capabilities].reject! { |c| c[:name] == "nested_virtualization" }
        
        if value
          @catlet[:capabilities] << { name: "nested_virtualization" }
        end
      end
      
      # Secure boot support
      def enable_secure_boot=(value)
        @enable_secure_boot = value
        ensure_catlet_hash!
        @catlet[:capabilities] ||= []
        @catlet[:capabilities].reject! { |c| c[:name] == "secure_boot" }
        
        if value
          @catlet[:capabilities] << { name: "secure_boot" }
        end
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
        vhd: "VHD",
        shared_vhd: "SharedVHD", 
        dvd: "DVD",
        vhd_set: "VHDSet"
      }.freeze
      
      def add_drive(name, size: nil, type: :vhd, source: nil, **options)
        # Validate Unix-style naming (warn but don't fail)
        unless name =~ /^(sd[a-z]|hd[a-z]|vd[a-z]|dvd|cdrom)$/
          puts "Warning: Drive name '#{name}' doesn't follow Unix convention (sda, sdb, etc.)"
        end
        
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
      
      def add_fodder_gene(geneset, gene, variables: nil, **options)
        # Build proper gene reference syntax: gene:<geneset>:<gene>
        gene_ref = "gene:#{geneset}:#{gene}"
        
        ensure_catlet_hash!
        @catlet[:genes] ||= []
        
        gene_config = { name: gene_ref }
        
        # Add variables if specified - must be an array of variable objects per spec
        if variables && variables.any?
          gene_config[:variables] = variables
        end
        
        # Add any other options
        gene_config.merge!(options) if options.any?
        
        @catlet[:genes] << gene_config
        
        gene_config
      end
      
      # ============================================================
      # FODDER HELPERS
      # ============================================================
      
      def cloud_config(name, content = nil, &block)
        @fodder ||= []
        
        if block_given?
          # DSL-style configuration
          config_data = {}
          yield config_data
          content = config_data
        end
        
        @fodder << {
          name: name,
          type: "cloud-config",
          content: content
        }
      end
      
      def shell_script(name, content)
        @fodder ||= []
        @fodder << {
          name: name,
          type: "shellscript", 
          content: content
        }
      end

      # Helper method to extract Vagrant cloud-init configuration
      def extract_vagrant_cloud_init_config(machine)
        return [] unless machine.config.vm.respond_to?(:cloud_init)
        return [] unless machine.config.vm.cloud_init

        cloud_init_configs = []
        
        # Handle multiple cloud-init configurations
        cloud_init_list = machine.config.vm.cloud_init.is_a?(Array) ? 
          machine.config.vm.cloud_init : [machine.config.vm.cloud_init]
        
        cloud_init_list.each_with_index do |cloud_init_config, index|
          next unless cloud_init_config
          
          fodder_item = convert_cloud_init_to_fodder(cloud_init_config, index)
          cloud_init_configs << fodder_item if fodder_item
        end
        
        cloud_init_configs
      end

      private

      # Convert Vagrant cloud-init configuration to Eryph fodder format
      def convert_cloud_init_to_fodder(cloud_init_config, index = 0)
        return nil unless cloud_init_config.content_type
        
        # Map Vagrant content types to Eryph fodder types
        fodder_type = map_content_type_to_fodder_type(cloud_init_config.content_type)
        return nil unless fodder_type
        
        # Generate name based on type and index
        name = "vagrant-cloud-init-#{fodder_type}"
        name += "-#{index}" if index > 0
        
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
        if cloud_init_config.inline
          process_cloud_init_content(cloud_init_config.inline, cloud_init_config.content_type)
        elsif cloud_init_config.path && File.exist?(cloud_init_config.path)
          content = File.read(cloud_init_config.path)
          process_cloud_init_content(content, cloud_init_config.content_type)
        else
          nil
        end
      end

      # Process cloud-init content based on content type
      def process_cloud_init_content(content, content_type)
        case content_type
        when 'text/cloud-config'
          # Parse YAML content into hash for cloud-config
          begin
            YAML.safe_load(content)
          rescue
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