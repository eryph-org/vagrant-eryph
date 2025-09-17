# frozen_string_literal: true

require_relative '../helpers/cloud_init'

module VagrantPlugins
  module Eryph
    module Actions
      class PrepareCloudInit
        def initialize(app, _env)
          @app = app
        end

        def call(env)
          env[:machine].provider_config
          ui = env[:ui]

          # Initialize cloud-init helper
          cloud_init = Helpers::CloudInit.new(env[:machine])

          ui.info('Preparing cloud-init configuration...')

          # Generate complete fodder configuration (auto + user)
          fodder = cloud_init.generate_complete_fodder

          if fodder.any?
            ui.info("Generated #{fodder.length} cloud-init fodder entries:")

            # Log fodder details with content
            fodder.each do |item|
              if item[:source]
                # Gene fodder - show name if available, otherwise source
                display_name = item[:name] || item[:source]
                ui.detail("  - #{display_name} (gene)")
              else
                # Regular fodder
                ui.detail("  - #{item[:name]} (#{item[:type]})")
              end
            end
          end

          # Store fodder in environment for use by create action
          env[:catlet_fodder] = fodder

          @app.call(env)
        end
      end
    end
  end
end
