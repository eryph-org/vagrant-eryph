# frozen_string_literal: true

require_relative 'actions'
require_relative 'helpers/eryph_client'
require 'eryph'

# Import Vagrant's UNSET_VALUE constant
UNSET_VALUE = Vagrant::Plugin::V2::Config::UNSET_VALUE

module VagrantPlugins
  module Eryph
    class Provider < Vagrant.plugin('2', :provider)
      # This class method caches status for all catlets within
      # the Eryph project. A specific catlet's status
      # may be refreshed by passing :refresh => true as an option.
      def self.eryph_catlet(machine, opts = {})
        client = Helpers::EryphClient.new(machine)

        # load status of catlets if it has not been done before
        @eryph_catlets ||= client.list_catlets || []

        if opts[:refresh] && machine.id
          # refresh the catlet status for the given machine
          @eryph_catlets.delete_if { |c| c.id == machine.id }
          catlet = client.get_catlet(machine.id)
          @eryph_catlets << catlet if catlet
        elsif machine.id
          # lookup catlet status for the given machine
          catlet = Array(@eryph_catlets).find { |c| c.id == machine.id }
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
        require 'log4r'
        logger = Log4r::Logger.new('vagrant::eryph::provider')

        catlet = Provider.eryph_catlet(@machine)
        logger.debug("ssh_info catlet status: #{catlet&.status}")

        # Return nil if catlet doesn't exist or isn't running
        return nil unless catlet
        return nil unless catlet.status&.downcase == 'running'

        # Get IP address from catlet networks
        ip_address = extract_ip_address(catlet)
        logger.debug("ssh_info extracted IP: #{ip_address}")
        return nil unless ip_address

        {
          host: ip_address,
          username: 'vagrant'
        }
      end

      # This should return the state of the machine within this provider.
      # The state must be an instance of {MachineState}.
      def state
        catlet = Provider.eryph_catlet(@machine) if @machine.id

        state_id = if catlet&.status
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

        catlet.networks.each_with_index do |network, _idx|
          # Only check floating port IP addresses (internal IPs are not accessible from outside)
          next unless network.respond_to?(:floating_port) && network.floating_port

          next unless network.floating_port.respond_to?(:ip_v4_addresses) &&
                      network.floating_port.ip_v4_addresses &&
                      !network.floating_port.ip_v4_addresses.empty?

          ip = network.floating_port.ip_v4_addresses.first
          return ip
        end
        nil
      end

      def map_catlet_state_to_vagrant(eryph_status)
        case eryph_status.downcase
        when 'running'
          :running
        when 'stopped'
          :stopped
        when 'pending'
          :unknown # Pending could be starting or stopping - we don't know which
        when 'error'
          :error
        else
          :unknown
        end
      end
    end
  end
end
