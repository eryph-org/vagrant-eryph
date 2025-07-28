module VagrantPlugins
  module Eryph
    module Actions
      class StartCatlet
        def initialize(app, env)
          @app = app
        end

        def call(env)
          return @app.call(env) unless env[:machine].id

          ui = env[:ui]
          client = env[:eryph_client]

          # Check current state
          catlet = Provider.eryph_catlet(env[:machine])
          
          if catlet.status&.downcase == 'running'
            ui.info("Catlet is already running")
            return @app.call(env)
          end

          ui.info("Starting catlet...")
          client.start_catlet(env[:machine].id)
          ui.info("Catlet started successfully")

          @app.call(env)
        rescue => e
          ui.error("Failed to start catlet: #{e.message}")
          raise e
        end
      end
    end
  end
end