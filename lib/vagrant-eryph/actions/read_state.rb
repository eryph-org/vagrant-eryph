# frozen_string_literal: true

module VagrantPlugins
  module Eryph
    module Actions
      class ReadState
        def initialize(app, _env)
          @app = app
        end

        def call(env)
          env[:machine_state_id] = read_state(env)
          @app.call(env)
        end

        private

        def read_state(env)
          return :not_created unless env[:machine].id

          begin
            catlet = Provider.eryph_catlet(env[:machine], refresh: true)

            if catlet.respond_to?(:status) && catlet.status
              map_catlet_state_to_vagrant(catlet.status)
            else
              :not_created
            end
          rescue StandardError => e
            env[:ui].warn("Error reading catlet state: #{e.message}")
            :unknown
          end
        end

        def map_catlet_state_to_vagrant(eryph_status)
          case eryph_status.downcase
          when 'running'
            :running
          when 'stopped'
            :stopped
          when 'pending'
            :unknown
          when 'error'
            :error
          else
            :unknown
          end
        end
      end
    end
  end
end
