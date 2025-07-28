module VagrantPlugins
  module Eryph
    module Actions
      class ReadSSHInfo
        def initialize(app, env)
          @app = app
        end

        def call(env)
          env[:machine_ssh_info] = read_ssh_info(env)
          @app.call(env)
        end

        private

        def read_ssh_info(env)
          return nil unless env[:machine].id

          config = env[:machine].provider_config
          
          # Get catlet information
          catlet = Provider.eryph_catlet(env[:machine])
          return nil unless catlet&.status&.downcase == 'running'

          # Extract IP address from catlet
          ip_address = extract_ip_address(catlet)
          return nil unless ip_address

          ssh_info = {
            host: ip_address,
            username: 'vagrant'
          }

          # For Windows catlets, use WinRM if enabled
          if config.windows_catlet? && config.enable_winrm
            ssh_info.merge!({
              port: 5985,
              transport: :winrm,
              password: config.vagrant_password
            })
          else
            # For Linux catlets, use SSH
            private_key_path = env[:machine].data_dir.join('private_key')
            ssh_info.merge!({
              port: 22,
              transport: :ssh,
              private_key_path: [private_key_path.to_s]
            })
          end

          ssh_info
        end

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
      end
    end
  end
end