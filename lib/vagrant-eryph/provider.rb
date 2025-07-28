require_relative 'actions'
require_relative 'helpers/eryph_client'
require 'eryph'

module VagrantPlugins
  module Eryph
    class Provider < Vagrant.plugin('2', :provider)
      
      # This class method caches status for all catlets within
      # the Eryph project. A specific catlet's status
      # may be refreshed by passing :refresh => true as an option.
      def self.eryph_catlet(machine, opts = {})
        client = Helpers::EryphClient.new(machine)

        # load status of catlets if it has not been done before
        unless @eryph_catlets
          @eryph_catlets = client.list_catlets || []
        end

        if opts[:refresh] && machine.id
          # refresh the catlet status for the given machine
          @eryph_catlets.delete_if { |c| c.id == machine.id }
          catlet = client.get_catlet(machine.id)
          @eryph_catlets << catlet if catlet
        else
          # lookup catlet status for the given machine
          catlet = Array(@eryph_catlets).find { |c| c.id == machine.id } if machine.id
        end

        # if lookup by id failed, check for a catlet with a matching name
        # and set the id to ensure vagrant stores locally
        unless catlet
          name = machine.config.vm.hostname || machine.name
          catlet = @eryph_catlets.find { |c| c.name == name.to_s }
          machine.id = catlet.id.to_s if catlet
        end

        catlet || OpenStruct.new(status: 'not_created')
      end

      def initialize(machine)
        @machine = machine
      end

      def action(name)
        # Attempt to get the action method from the Actions module if it
        # exists, otherwise return nil to show that we don't support the
        # given action.
        action_method = "action_#{name}"
        return Actions.send(action_method) if Actions.respond_to?(action_method)
        nil
      end

      # This method is called if the underlying machine ID changes. Providers
      # can use this method to load in new data for the actual backing
      # machine or to realize that the machine is now gone (the ID can
      # become `nil`).
      def machine_id_changed
        # Clear cached catlets when machine ID changes
        @eryph_catlets = nil if defined?(@eryph_catlets)
      end

      # This should return a hash of information that explains how to
      # SSH into the machine. If the machine is not at a point where
      # SSH is even possible, then `nil` should be returned.
      def ssh_info
        catlet = Provider.eryph_catlet(@machine)
        
        # Return nil if catlet doesn't exist or isn't running
        return nil unless catlet
        return nil unless catlet.status&.downcase == 'running'

        # Get IP address from catlet networks
        ip_address = extract_ip_address(catlet)
        
        # Return nil if no IP found - this tells Vagrant to keep waiting
        return nil unless ip_address

        config = @machine.provider_config

        # For Windows catlets with WinRM enabled
        if config.windows_catlet? && config.enable_winrm
          return {
            host: ip_address,
            port: 5985,
            username: 'vagrant',
            password: config.vagrant_password,
            transport: :winrm
          }
        else
          # For Linux catlets or Windows without WinRM, use SSH
          ssh_info = {
            host: ip_address,
            port: 22,
            username: 'vagrant'
          }

          # Add private key path if available
          private_key_path = @machine.data_dir.join('private_key')
          ssh_info[:private_key_path] = [private_key_path.to_s] if private_key_path.exist?

          ssh_info
        end
      end

      # This should return the state of the machine within this provider.
      # The state must be an instance of {MachineState}.
      def state
        catlet = Provider.eryph_catlet(@machine) if @machine.id
        
        state_id = if catlet && catlet.status
                     map_catlet_state_to_vagrant(catlet.status)
                   else
                     :not_created
                   end
        
        long = short = state_id.to_s
        Vagrant::MachineState.new(state_id, short, long)
      end

      private

      def extract_ip_address(catlet)
        # Extract IP address from catlet networks
        return nil unless catlet.respond_to?(:networks) && catlet.networks
        
        catlet.networks.each do |network|
          # Only check floating port IP addresses (internal IPs are not accessible from outside)
          if network.respond_to?(:floating_port) && network.floating_port
            if network.floating_port.respond_to?(:ip_v4_addresses) && 
               network.floating_port.ip_v4_addresses && 
               !network.floating_port.ip_v4_addresses.empty?
              return network.floating_port.ip_v4_addresses.first
            end
          end
          
          # TODO: Add support for reported IP addresses once available
        end

        nil
      end

      def map_catlet_state_to_vagrant(eryph_status)
        case eryph_status.downcase
        when 'running'
          :running
        when 'stopped', 'stopping'
          :stopped
        when 'starting'
          :starting
        when 'error', 'failed'
          :error
        else
          :unknown
        end
      end
    end
  end
end