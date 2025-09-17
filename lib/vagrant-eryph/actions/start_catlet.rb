# frozen_string_literal: true

module VagrantPlugins
  module Eryph
    module Actions
      class StartCatlet
        def initialize(app, _env)
          @app = app
        end

        def call(env)
          return @app.call(env) unless env[:machine].id

          ui = env[:ui]
          client = env[:eryph_client]

          # Check current state
          catlet = Provider.eryph_catlet(env[:machine])

          if catlet.status&.downcase == 'running'
            ui.info('Catlet is already running')
            return @app.call(env)
          end

          ui.info('Starting catlet...')
          client.start_catlet(env[:machine].id)
          ui.info('Catlet started successfully')

          # Clear cached catlet status to force refresh on next lookup
          Provider.instance_variable_set(:@eryph_catlets, nil)

          @app.call(env)
        end
      end
    end
  end
end
