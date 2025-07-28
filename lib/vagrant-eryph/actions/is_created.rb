module VagrantPlugins
  module Eryph
    module Actions
      class IsCreated
        def initialize(app, env)
          @app = app
        end

        def call(env)
          # Check if the machine has been created by looking for a machine ID
          # and verifying the catlet exists in Eryph
          env[:result] = env[:machine].id && catlet_exists?(env)
          @app.call(env)
        end

        private

        def catlet_exists?(env)
          return false unless env[:machine].id

          begin
            catlet = Provider.eryph_catlet(env[:machine])
            catlet && catlet.respond_to?(:status) && catlet.status != 'not_created'
          rescue => e
            env[:ui].warn("Error checking catlet existence: #{e.message}")
            false
          end
        end
      end
    end
  end
end