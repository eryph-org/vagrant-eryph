module VagrantPlugins
  module Eryph
    module Actions
      class MessageAlreadyCreated
        def initialize(app, env)
          @app = app
        end

        def call(env)
          env[:ui].info("Catlet is already created and running.")
          @app.call(env)
        end
      end
    end
  end
end