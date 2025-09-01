# frozen_string_literal: true

module VagrantPlugins
  module Eryph
    module Actions
      class IsStopped
        def initialize(app, _env)
          @app = app
        end

        def call(env)
          # Check if the catlet is in a stopped state
          catlet = Provider.eryph_catlet(env[:machine])
          env[:result] = catlet && catlet.status&.downcase == 'stopped'
          @app.call(env)
        end
      end
    end
  end
end
