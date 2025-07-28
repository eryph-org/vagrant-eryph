module VagrantPlugins
  module Eryph
    module Actions
      class MessageWillNotDestroy
        def initialize(app, env)
          @app = app
        end

        def call(env)
          env[:ui].info("Catlet will not be destroyed, since the confirmation was declined.")
          @app.call(env)
        end
      end
    end
  end
end