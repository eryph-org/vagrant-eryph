module VagrantPlugins
  module Eryph
    module Errors
      class EryphError < Vagrant::Errors::VagrantError
        attr_reader :problem_details
        
        def initialize(message = nil, problem_details = nil)
          @problem_details = problem_details
          super(message)
        end
        
        error_namespace("vagrant_eryph.errors")
        
        def has_problem_details?
          !@problem_details.nil?
        end
        
        def friendly_message
          if has_problem_details? && @problem_details.respond_to?(:friendly_message)
            @problem_details.friendly_message
          else
            super
          end
        end
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
      
      # Helper method to convert API errors to our enhanced errors
      def self.from_api_error(api_error, error_class = EryphError)
        if api_error.is_a?(::Eryph::Compute::ProblemDetailsError)
          error_class.new(api_error.friendly_message, api_error)
        elsif api_error.respond_to?(:message)
          error_class.new(api_error.message, api_error)
        else
          error_class.new(api_error.to_s, api_error)
        end
      end
    end
  end
end