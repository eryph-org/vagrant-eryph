# frozen_string_literal: true

require_relative '../helpers/eryph_client'
require_relative '../errors'

module VagrantPlugins
  module Eryph
    module Actions
      class ConnectEryph
        def initialize(app, _env)
          @app = app
        end

        def call(env)
          # Initialize Eryph client and store it in the environment
          env[:eryph_client] = Helpers::EryphClient.new(env[:machine])

          # Test the connection by calling client (which tests connectivity)
          env[:eryph_client].client

          # Ensure the project exists (create if needed and auto_create_project is enabled)
          config = env[:machine].provider_config
          env[:eryph_client].ensure_project_exists(config.project) if config.project

          @app.call(env)
        rescue ::Eryph::ClientRuntime::CredentialsNotFoundError => e
          raise Errors::CredentialsError, e.message
        rescue ::Eryph::ClientRuntime::TokenRequestError => e
          raise Errors::APIConnectionError, e.message
        end
      end
    end
  end
end
