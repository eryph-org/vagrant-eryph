module VagrantPlugins
  module Eryph
    module Actions
      class DestroyCatlet
        def initialize(app, env)
          @app = app
        end

        def call(env)
          return @app.call(env) unless env[:machine].id

          ui = env[:ui]
          client = env[:eryph_client]

          ui.info("Destroying catlet...")
          client.destroy_catlet(env[:machine].id)
          
          # Clear the machine ID since it no longer exists
          env[:machine].id = nil
          
          ui.info("Catlet destroyed successfully")

          @app.call(env)
        rescue => e
          ui.error("Failed to destroy catlet: #{e.message}")
          raise e
        end
      end
    end
  end
end