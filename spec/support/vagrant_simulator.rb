# Vagrant Simulation Mock - Realistic Vagrant behavior for unit testing
# This simulates REAL Vagrant classes with CORRECT behavior and constants

require 'pathname'
require 'fileutils'
require 'json'

# Global Vagrant module simulation
module Vagrant
  # Simulate the main plugin registration method
  def self.plugin(version, type = nil)
    if type.nil?
      Plugin::V2::Plugin  # Return plugin base class
    else
      case type
      when :config
        Plugin::V2::Config
      when :provider  
        Plugin::V2::Provider
      else
        Object
      end
    end
  end
  
  # Simulate other Vagrant modules that might be referenced
  module Action
    module Builtin
      # Mock for action includes
    end
  end
  
  module Errors
    class VagrantError < StandardError
      def self.error_namespace(namespace)
        # Mock error namespace method
      end
      
      def self.error_key(key)
        # Mock error key method
      end
    end
  end
  
  # Machine state class
  class MachineState
    attr_reader :id, :short_description, :long_description
    
    def initialize(id, short_description, long_description = nil)
      @id = id
      @short_description = short_description
      @long_description = long_description || short_description
    end
    
    def to_s
      @short_description
    end
  end
  
  module Plugin
    module V2
      # Plugin base class
      class Plugin
        def self.name(plugin_name = nil)
          # Plugin name registration
        end
        
        def self.description(desc = nil)
          # Plugin description
        end
        
        def self.config(name, scope = nil, &block)
          # Config registration
        end
        
        def self.provider(name, options = {}, &block)
          # Provider registration
        end
      end
      
      # Provider base class
      class Provider
        def initialize(machine)
          @machine = machine
        end
      end
      # Realistic Config base class that matches real Vagrant behavior
      class Config
        # EXACT constant from real Vagrant - not our fake version!
        UNSET_VALUE = :__UNSET__VALUE__
        
        def initialize
          # Real Vagrant initializes everything to UNSET_VALUE
          # Subclasses should call super and set their own instance variables
        end
        
        def finalize!
          # Base implementation does nothing - subclasses override
          # This matches real Vagrant::Plugin::V2::Config behavior
        end
        
        def validate(machine)
          # Return hash of errors - empty hash means no errors
          # This matches real Vagrant validation interface
          errors = {}
          
          # Add any validation errors discovered
          detected = _detected_errors
          if detected && detected.any?
            errors[self.class.name] = detected
          end
          
          errors
        end
        
        def merge(other)
          # Real Vagrant merge implementation - copy instance variables
          result = self.class.new
          
          # Merge instance variables from both objects
          [self, other].each do |obj|
            obj.instance_variables.each do |key|
              # Skip private variables (start with double underscore)
              next if key.to_s.start_with?("@__")
              
              value = obj.instance_variable_get(key)
              result.instance_variable_set(key, value) unless value == UNSET_VALUE
            end
          end
          
          result
        end
        
        protected
        
        def _detected_errors
          # Subclasses can override to add validation errors
          []
        end
      end
    end
  end
end

# Add UNSET_VALUE to global namespace for compatibility
UNSET_VALUE = Vagrant::Plugin::V2::Config::UNSET_VALUE unless defined?(UNSET_VALUE)

module VagrantSimulator
  # Simulated UI that captures messages for testing
  class UI
    attr_reader :messages
    
    def initialize
      @messages = []
    end
    
    def info(message)
      @messages << { level: :info, message: message }
      puts "INFO: #{message}" if ENV['VAGRANT_DEBUG']
    end
    
    def warn(message)
      @messages << { level: :warn, message: message }
      puts "WARN: #{message}" if ENV['VAGRANT_DEBUG']
    end
    
    def error(message)
      @messages << { level: :error, message: message }
      puts "ERROR: #{message}" if ENV['VAGRANT_DEBUG']
    end
    
    def success(message)
      @messages << { level: :success, message: message }
      puts "SUCCESS: #{message}" if ENV['VAGRANT_DEBUG']
    end
    
    def detail(message)
      @messages << { level: :detail, message: message }
      puts "DETAIL: #{message}" if ENV['VAGRANT_DEBUG']
    end
    
    def clear_messages
      @messages.clear
    end
  end
  
  # Simulated Machine that behaves like Vagrant::Machine
  class Machine
    attr_accessor :id, :name, :provider_config
    attr_reader :ui, :config, :env, :data_dir
    
    def initialize(name, provider, config, env = nil)
      @name = name
      @provider = provider
      @config = config
      @env = env || Environment.new
      @ui = UI.new
      @provider_config = nil
      @id = nil
      @data_dir = DataDir.new
    end
    
    def state
      # Return a state object - would be provided by the provider
      State.new(:not_created, "The machine is not created", :not_created)
    end
    
    # Allow setting up different test scenarios
    def simulate_state(state_id, short_description, long_description = nil)
      @simulated_state = State.new(state_id, short_description, long_description)
    end
    
    private
    
    def state
      @simulated_state || State.new(:not_created, "Not created", "The machine is not created")
    end
  end
  
  # Simulated data directory
  class DataDir
    def join(path)
      # Return a pathname-like object
      DataPath.new("/tmp/vagrant/#{path}")
    end
  end
  
  class DataPath
    def initialize(path)
      @path = path
    end
    
    def exist?
      false  # For testing, assume files don't exist initially
    end
    
    def to_s
      @path
    end
  end
  
  # Simulated state object
  class State
    attr_reader :id, :short_description, :long_description
    
    def initialize(id, short_description, long_description = nil)
      @id = id
      @short_description = short_description
      @long_description = long_description
    end
    
    def to_s
      @short_description
    end
  end
  
  # Simulated Environment
  class Environment
    attr_reader :root_path, :home_path
    
    def initialize(opts = {})
      @root_path = opts[:root_path] || Dir.pwd
      @home_path = opts[:home_path] || File.join(Dir.home, '.vagrant.d')
    end
  end
  
  # Simulated VM config
  class VMConfig
    attr_accessor :hostname, :box
    
    def initialize
      @hostname = nil
      @box = nil
    end
  end
  
  # Simulated machine config
  class MachineConfig
    attr_reader :vm
    
    def initialize
      @vm = VMConfig.new
    end
  end
  
  # Test helper methods
  module TestHelpers
    def create_machine(name = 'default', provider = :eryph)
      config = MachineConfig.new
      machine = Machine.new(name, provider, config)
      
      # Set up realistic defaults
      config.vm.hostname = name.to_s
      
      machine
    end
    
    def simulate_vagrant_lifecycle(config_class)
      # Simulate the real Vagrant config lifecycle
      config = config_class.new
      config.finalize!
      
      machine = create_machine
      errors = config.validate(machine)
      
      {
        config: config,
        machine: machine,
        errors: errors
      }
    end
    
    def expect_validation_error(config, machine, error_message)
      errors = config.validate(machine)
      expect(errors).not_to be_empty, "Expected validation errors but got none"
      
      error_list = errors.values.flatten
      expect(error_list).to include(error_message), 
        "Expected error '#{error_message}' but got: #{error_list.inspect}"
    end
    
    def expect_no_validation_errors(config, machine)
      errors = config.validate(machine)
      
      # Check if any error arrays are non-empty
      has_errors = errors.any? { |key, error_list| error_list && error_list.any? }
      expect(has_errors).to be(false), "Expected no validation errors but got: #{errors.inspect}"
    end
  end
end