require 'yaml'
require 'digest'
require_relative 'ssh_key'

module VagrantPlugins
  module Eryph
    module Helpers
      class CloudInit
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
          # Use Vagrant's built-in guest detection first
          guest = @machine.config.vm.guest
          return guest if [:windows, :linux].include?(guest)
          
          # Fallback to gene name heuristic for backward compatibility
          if @config.windows_catlet?
            :windows
          else
            :linux
          end
        end

        private

        def generate_linux_user_fodder
          ssh_key_data = SSHKey.ensure_key_pair_exists(@machine)

          cloud_config = {
            'users' => [
              {
                'name' => 'vagrant',
                'sudo' => ['ALL=(ALL) NOPASSWD:ALL'],
                'shell' => '/bin/bash',
                'groups' => ['sudo'],
                'lock_passwd' => false,
                'passwd' => generate_password_hash('vagrant'),
                'ssh_authorized_keys' => [ssh_key_data[:public_key]]
              }
            ],
            'package_update' => true,
            'packages' => ['openssh-server'],
            'ssh_pwauth' => false,
            'disable_root' => false
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
          fodder = []

          # Windows user setup via cloud-config
          cloud_config = {
            'users' => [
              {
                'name' => 'vagrant',
                'passwd' => generate_password_hash(@config.vagrant_password),
                'groups' => ['Administrators'],
                'inactive' => false
              }
            ]
          }

          fodder << {
            name: 'vagrant-user-setup-windows',
            type: 'cloud-config',
            content: cloud_config
          }

          # WinRM setup if enabled
          if @config.enable_winrm
            winrm_script = generate_winrm_setup_script
            fodder << {
              name: 'winrm-setup',
              type: 'shellscript',
              content: winrm_script
            }
          end

          fodder
        end

        def generate_winrm_setup_script
          <<~POWERSHELL
            #ps1_sysnative
            # Enable WinRM for Vagrant
            
            # Enable PowerShell remoting
            Enable-PSRemoting -Force -SkipNetworkProfileCheck
            
            # Configure WinRM service
            winrm quickconfig -q
            winrm quickconfig -transport:http
            winrm set winrm/config '@{MaxTimeoutms="1800000"}'
            winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="300"}'
            winrm set winrm/config/service '@{AllowUnencrypted="true"}'
            winrm set winrm/config/service/auth '@{Basic="true"}'
            winrm set winrm/config/client/auth '@{Basic="true"}'
            winrm set winrm/config/listener?Address=*+Transport=HTTP '@{Port="5985"}'
            
            # Configure Windows Firewall
            netsh advfirewall firewall set rule group="Windows Remote Administration" new enable=yes
            netsh advfirewall firewall set rule name="Windows Remote Management (HTTP-In)" new enable=yes action=allow
            
            # Set WinRM service to automatic start
            Set-Service winrm -startuptype "auto"
            Restart-Service winrm
            
            Write-Host "WinRM setup completed successfully"
          POWERSHELL
        end


        def generate_password_hash(password)
          # Generate SHA-512 hash for the password (common Linux format)
          # In a real implementation, you might want to use a more secure method
          salt = SecureRandom.hex(8)
          password_hash = Digest::SHA512.hexdigest("#{password}#{salt}")
          "$6$#{salt}$#{password_hash}"
        end
      end
    end
  end
end