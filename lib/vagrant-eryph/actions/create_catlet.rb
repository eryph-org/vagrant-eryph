require 'yaml'
require 'json'

module VagrantPlugins
  module Eryph
    module Actions
      class CreateCatlet
        def initialize(app, env)
          @app = app
        end

        def call(env)
          config = env[:machine].provider_config
          ui = env[:ui]
          client = env[:eryph_client]

          # Build catlet creation request as hash (like AWS provider)
          catlet_config = build_catlet_config(env)

          ui.info("Creating catlet with configuration:")
          ui.info("  Name: #{catlet_config[:name]}")
          ui.info("  Parent Gene: #{catlet_config[:parent]}")
          ui.info("  Project: #{catlet_config[:project]}")

          # Create and start the catlet (client handles the full lifecycle)
          operation_result = client.create_catlet(catlet_config)

          # Store the catlet ID from the operation result
          # The client now finds the catlet by name after creation completes
          if operation_result && operation_result.respond_to?(:catlet_id)
            env[:machine].id = operation_result.catlet_id
            ui.info("Catlet provisioned successfully with ID: #{operation_result.catlet_id}")
          else
            raise "Failed to get catlet ID from operation result"
          end

          @app.call(env)
        rescue => e
          ui.error("Failed to create catlet: #{e.message}")
          raise e
        end

        private

        def build_catlet_config(env)
          config = env[:machine].provider_config
          fodder = env[:catlet_fodder] || []

          # Use the new effective_catlet_configuration method
          catlet_config = config.effective_catlet_configuration(env[:machine])

          # Add fodder configuration if present
          if fodder.any?
            catlet_config[:fodder] = fodder.map do |item|
              {
                name: item[:name],
                type: item[:type],
                content: serialize_fodder_content(item[:content])
              }
            end
          end

          catlet_config
        end

        def serialize_fodder_content(content)
          case content
          when Hash
            # Convert hash to YAML for cloud-config (remove YAML document separator)
            content.to_yaml.sub(/^---\n/, '')
          when String
            content
          else
            content.to_s
          end
        end
      end
    end
  end
end