module VagrantPlugins
  module Eryph
    class Config < Vagrant.plugin('2', :config)
      # Eryph-specific configuration
      attr_accessor :project
      attr_accessor :catlet_name
      attr_accessor :config_name
      attr_accessor :endpoint_name
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
      
      # Catlet configuration - direct hash structure
      attr_accessor :catlet
      
      # Legacy support for backward compatibility (will be deprecated)
      attr_accessor :parent_gene
      attr_accessor :cpu
      attr_accessor :memory
      attr_accessor :drives
      attr_accessor :networks
      
      def initialize
        @project = UNSET_VALUE
        @parent_gene = UNSET_VALUE
        @catlet_name = UNSET_VALUE
        @config_name = UNSET_VALUE
        @endpoint_name = UNSET_VALUE
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
        
        # New catlet configuration
        @catlet = UNSET_VALUE
        
        # Legacy configuration (for backward compatibility)
        @cpu = UNSET_VALUE
        @memory = UNSET_VALUE
        @drives = UNSET_VALUE
        @networks = UNSET_VALUE
      end

      def finalize!
        @project = nil if @project == UNSET_VALUE
        @parent_gene = 'dbosoft/ubuntu:22.04' if @parent_gene == UNSET_VALUE
        @catlet_name = nil if @catlet_name == UNSET_VALUE
        @config_name = 'default' if @config_name == UNSET_VALUE
        @endpoint_name = nil if @endpoint_name == UNSET_VALUE
        @auto_create_project = true if @auto_create_project == UNSET_VALUE
        
        @client_id = nil if @client_id == UNSET_VALUE
        @configuration_name = 'default' if @configuration_name == UNSET_VALUE
        
        # SSL defaults - disable verification for localhost
        @ssl_verify = self.determine_ssl_verify_default if @ssl_verify == UNSET_VALUE
        @ssl_ca_file = nil if @ssl_ca_file == UNSET_VALUE
        
        @auto_config = true if @auto_config == UNSET_VALUE
        @enable_winrm = true if @enable_winrm == UNSET_VALUE
        @vagrant_password = 'vagrant' if @vagrant_password == UNSET_VALUE
        @ssh_key_injection = :direct if @ssh_key_injection == UNSET_VALUE
        @fodder = [] if @fodder == UNSET_VALUE
        
        # Initialize catlet configuration as empty hash if not set
        @catlet = {} if @catlet == UNSET_VALUE
        
        # Legacy configuration defaults (for backward compatibility)
        @cpu = nil if @cpu == UNSET_VALUE
        @memory = nil if @memory == UNSET_VALUE
        @drives = [] if @drives == UNSET_VALUE
        @networks = [] if @networks == UNSET_VALUE
      end

      def validate(machine)
        errors = _detected_errors

        # Validate required fields - check both catlet hash and legacy parent_gene
        parent = (@catlet&.dig(:parent) || @catlet&.dig('parent')) || @parent_gene
        errors << 'parent is required (set in catlet hash or parent_gene)' if !parent
        
        # Project validation - only warn if auto_create_project is disabled
        if !@project && !@auto_create_project
          errors << 'project is required when auto_create_project is disabled'
        end

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
    end
  end
end