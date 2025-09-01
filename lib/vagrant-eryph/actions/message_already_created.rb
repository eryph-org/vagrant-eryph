# frozen_string_literal: true

module VagrantPlugins
  module Eryph
    module Actions
      class MessageAlreadyCreated
        def initialize(app, _env)
          @app = app
        end

        def call(env)
          env[:ui].info('Catlet is already created and running.')
          @app.call(env)
        end
      end
    end
  end
end
