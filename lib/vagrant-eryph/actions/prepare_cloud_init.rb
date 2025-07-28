require_relative '../helpers/cloud_init'

module VagrantPlugins
  module Eryph
    module Actions
      class PrepareCloudInit
        def initialize(app, env)
          @app = app
        end

        def call(env)
          config = env[:machine].provider_config
          ui = env[:ui]

          # Initialize cloud-init helper
          cloud_init = Helpers::CloudInit.new(env[:machine])

          ui.info("Preparing cloud-init configuration...")

          # Generate complete fodder configuration (auto + user)
          fodder = cloud_init.generate_complete_fodder

          if fodder.any?
            ui.info("Generated #{fodder.length} cloud-init fodder entries")
            
            # Log fodder details
            fodder.each do |item|
              ui.info("  - #{item[:name]} (#{item[:type]})")
            end
          else
            ui.info("No cloud-init configuration generated")
          end

          # Store fodder in environment for use by create action
          env[:catlet_fodder] = fodder

          @app.call(env)
        rescue => e
          ui.error("Failed to prepare cloud-init configuration: #{e.message}")
          raise e
        end
      end
    end
  end
end