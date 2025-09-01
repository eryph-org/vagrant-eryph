# frozen_string_literal: true

require 'yaml'
require 'digest'

module VagrantPlugins
  module Eryph
    module Helpers
      class CloudInit
        VAGRANT_PUBLIC_KEY = 'ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant'

        def initialize(machine)
          @machine = machine
          @config = machine.provider_config
          @ui = machine.ui
        end

        # Generate cloud-init fodder for Vagrant user setup
        def generate_vagrant_user_fodder
          return [] unless @config.auto_config

          if detect_os_type == :windows
            generate_windows_user_fodder
          else
            generate_linux_user_fodder
          end
        end

        # Merge auto-generated fodder with user-provided fodder
        def merge_fodder_with_user_config(auto_fodder)
          @config.merged_fodder(auto_fodder)
        end

        # Generate complete fodder configuration including user config
        def generate_complete_fodder
          auto_fodder = generate_vagrant_user_fodder

          # Add Vagrant cloud-init configuration if present
          cloud_init_fodder = @config.extract_vagrant_cloud_init_config(@machine)
          auto_fodder.concat(cloud_init_fodder) if cloud_init_fodder.any?

          merge_fodder_with_user_config(auto_fodder)
        end

        # Detect OS type using Vagrant's guest detection
        def detect_os_type
          guest = @machine.config.vm.guest
          guest if %i[windows linux].include?(guest)
        end

        # Get effective password - resolves :auto based on OS type
        def effective_password
          return @config.vagrant_password unless @config.vagrant_password == :auto

          guest = @machine.config.vm.guest
          if guest == :windows
            'InitialPassw0rd' # Eryph Windows default
          else
            'vagrant' # Standard Vagrant for Linux
          end
        end

        private

        def generate_linux_user_fodder
          cloud_config = {
            'users' => [
              {
                'name' => 'vagrant',
                'sudo' => ['ALL=(ALL) NOPASSWD:ALL'],
                'shell' => '/bin/bash',
                'groups' => ['adm'],
                'lock_passwd' => false,
                'plain_text_passwd' => effective_password,
                'ssh_authorized_keys' => [VAGRANT_PUBLIC_KEY]
              }
            ]
          }

          [
            {
              name: 'vagrant-user-setup',
              type: 'cloud-config',
              content: cloud_config
            }
          ]
        end

        def generate_windows_user_fodder
          # Always create vagrant user with config password
          cloud_config = {
            'users' => [
              {
                'name' => 'vagrant',
                'groups' => ['Administrators'],
                'passwd' => effective_password,
                'ssh_authorized_keys' => [VAGRANT_PUBLIC_KEY]
              }
            ]
          }

          [
            {
              name: 'vagrant-user-setup-windows',
              type: 'cloud-config',
              content: cloud_config
            }
          ]
        end
      end
    end
  end
end
