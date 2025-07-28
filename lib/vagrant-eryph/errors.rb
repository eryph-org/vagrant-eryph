module VagrantPlugins
  module Eryph
    module Errors
      class EryphError < Vagrant::Errors::VagrantError
        error_namespace("vagrant_eryph.errors")
      end

      class APIConnectionError < EryphError
        error_key(:api_connection_failed)
      end

      class CredentialsError < EryphError
        error_key(:credentials_not_found)
      end

      class CatletNotFoundError < EryphError
        error_key(:catlet_not_found)
      end

      class OperationFailedError < EryphError
        error_key(:operation_failed)
      end

      class ConfigurationError < EryphError
        error_key(:configuration_error)
      end
    end
  end
end