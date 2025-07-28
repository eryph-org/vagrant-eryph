module VagrantPlugins
  module Eryph
    module Actions
      class MessageNotCreated
        def initialize(app, env)
          @app = app
        end

        def call(env)
          env[:ui].error("Catlet has not been created. Run `vagrant up` first.")
          @app.call(env)
        end
      end
    end
  end
end