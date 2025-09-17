# frozen_string_literal: true

require 'yaml'
require 'json'

module VagrantPlugins
  module Eryph
    module Actions
      class CreateCatlet
        def initialize(app, _env)
          @app = app
        end

        def call(env)
          env[:machine].provider_config
          ui = env[:ui]
          client = env[:eryph_client]

          # Build catlet creation request as hash (like AWS provider)
          catlet_config = build_catlet_config(env)

          ui.info('Creating catlet with configuration:')
          ui.info("  Name: #{catlet_config[:name]}")
          ui.info("  Parent Gene: #{catlet_config[:parent]}")
          ui.info("  Project: #{catlet_config[:project]}")

          # Create and start the catlet (client handles the full lifecycle)
          operation_result = client.create_catlet(catlet_config)

          # Store the catlet ID from the operation result
          # The client handles creation and starting, now extract the catlet
          raise 'Catlet creation failed' unless operation_result&.completed?

          catlet = operation_result.catlet
          raise 'Failed to get catlet from operation result' unless catlet

          env[:machine].id = catlet.id
          ui.info("Catlet provisioned successfully with ID: #{catlet.id}")

          # Clear cached catlet status to force refresh on next lookup
          Provider.instance_variable_set(:@eryph_catlets, nil)

          @app.call(env)
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
              if item[:content]
                # Regular fodder with content - serialize the content
                item.merge(content: serialize_fodder_content(item[:content]))
              else
                # Gene fodder or other - copy as-is
                item
              end
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
