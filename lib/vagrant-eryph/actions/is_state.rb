# frozen_string_literal: true

module VagrantPlugins
  module Eryph
    module Actions
      class IsState
        def initialize(app, env, state)
          @app = app
          @state = state.to_s.downcase
        end

        def call(env)
          # Check if the catlet is in the specified state
          catlet = Provider.eryph_catlet(env[:machine])
          env[:result] = catlet && catlet.status&.downcase == @state
          @app.call(env)
        end
      end
    end
  end
end