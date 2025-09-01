# frozen_string_literal: true

module VagrantPlugins
  module Eryph
    module Actions
      class MessageNotCreated
        def initialize(app, _env)
          @app = app
        end

        def call(env)
          env[:ui].error('Catlet has not been created. Run `vagrant up` first.')
          @app.call(env)
        end
      end
    end
  end
end
