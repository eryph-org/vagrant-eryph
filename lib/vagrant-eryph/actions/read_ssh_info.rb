# frozen_string_literal: true

module VagrantPlugins
  module Eryph
    module Actions
      class ReadSSHInfo
        def initialize(app, _env)
          @app = app
        end

        def call(env)
          # Delegate to the provider's ssh_info method for consistency
          provider = env[:machine].provider
          env[:machine_ssh_info] = provider.ssh_info
          @app.call(env)
        end
      end
    end
  end
end
