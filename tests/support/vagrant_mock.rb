# Mock Vagrant module for testing without requiring full Vagrant installation

module Vagrant
  def self.plugin(version, type = nil)
    # When called with just version (e.g., Vagrant.plugin('2')), return PluginBase
    # When called with version and type, return specific base class
    if type.nil?
      PluginBase
    else
      case type
      when :config
        ConfigBase
      when :provider
        ProviderBase
      else
        Object
      end
    end
  end
  
  class PluginBase
    def self.name(plugin_name = nil)
      # Mock plugin name method
    end
    
    def self.description(desc = nil)
      # Mock plugin description method
    end
    
    def self.config(name, scope = nil, &block)
      # Mock config registration method
    end
    
    def self.provider(name, options = {}, &block)
      # Mock provider registration method
    end
    
    def self.command(name, options = {}, &block)
      # Mock command registration method
    end
  end
  
  class ConfigBase
    # Mock UNSET_VALUE constant that Vagrant uses
    UNSET_VALUE = :__unset_value__
    
    def initialize
      # Initialize any common config functionality
    end
    
    def finalize!
      # Mock finalize method
    end
    
    def validate(machine)
      # Mock validate method - return empty errors hash
      {}
    end
    
    # Mock _detected_errors method that Vagrant config classes use
    def _detected_errors
      []
    end
  end
  
  class ProviderBase
    def initialize(machine)
      @machine = machine
    end
  end
end

# Add UNSET_VALUE to the global namespace for compatibility
UNSET_VALUE = Vagrant::ConfigBase::UNSET_VALUE unless defined?(UNSET_VALUE)

# Mock UI for testing
class MockUI
  def error(message)
    puts "ERROR: #{message}"
  end
  
  def warn(message)
    puts "WARN: #{message}"
  end
  
  def info(message)
    puts "INFO: #{message}"
  end
end

# Mock Machine for testing
class MockMachine
  attr_reader :ui, :config, :provider_config
  
  def initialize
    @ui = MockUI.new
    @config = MockConfig.new
    @provider_config = nil
  end
  
  def data_dir
    # Return a mock directory object
    MockDataDir.new
  end
  
  def name
    "test-machine"
  end
end

# Mock data directory
class MockDataDir
  def join(filename)
    MockPath.new(File.join("/tmp/vagrant_test", filename))
  end
  
  def exist?
    true  # Assume directory exists for testing
  end
  
  def mkpath
    # Mock directory creation - do nothing for tests
    true
  end
end

# Mock path object
class MockPath
  def initialize(path)
    @path = path
  end
  
  def to_s
    @path
  end
  
  def exist?
    false  # For testing, assume keys don't exist initially
  end
end

# Mock File class for testing
module MockFileOperations
  def self.included(base)
    base.extend(ClassMethods)
  end
  
  module ClassMethods
    alias_method :original_write, :write if respond_to?(:write)
    alias_method :original_chmod, :chmod if respond_to?(:chmod)
    alias_method :original_read, :read if respond_to?(:read)
    
    def write(filename, data, offset = nil, **options)
      # Check if this is a MockPath
      if filename.is_a?(MockPath)
        # Mock write operation - just return length for tests
        return data.length
      else
        # Use original method if it exists, otherwise do nothing
        if respond_to?(:original_write)
          original_write(filename, data, offset, **options)
        else
          data.length
        end
      end
    end
    
    def chmod(mode, *filenames)
      # Check if any are MockPath objects
      mock_files = filenames.select { |f| f.is_a?(MockPath) }
      if mock_files.any?
        # Mock chmod operation - return number of files processed
        return filenames.length
      else
        # Use original method if it exists
        if respond_to?(:original_chmod)
          original_chmod(mode, *filenames)
        else
          filenames.length
        end
      end
    end
    
    def read(filename, length = nil, offset = nil, **options)
      # Check if this is a MockPath
      if filename.is_a?(MockPath)
        # Mock read operation - return test data
        if filename.to_s.include?('private_key')
          "-----BEGIN RSA PRIVATE KEY-----\ntest_private_key_data\n-----END RSA PRIVATE KEY-----"
        else
          "ssh-rsa test_public_key_data vagrant@test"
        end
      else
        # For real files, always use the original method to avoid breaking other systems (like Eryph)
        if respond_to?(:original_read)
          original_read(filename, length, offset, **options)
        else
          # Fallback to Ruby's built-in File.read if original method not available
          super(filename, length, offset, **options)
        end
      end
    end
  end
end

# Only include mock file operations when VAGRANT_ERYPH_TEST is set AND explicitly requested
# This prevents interference with other systems like Eryph client configuration reading
if ENV['VAGRANT_ERYPH_TEST'] == 'true' && ENV['VAGRANT_ERYPH_ENABLE_FILE_MOCKING'] == 'true'
  File.include(MockFileOperations)
end

class MockConfig
  attr_accessor :guest
  
  def initialize
    @guest = :linux  # Default to Linux
  end
  
  def vm
    self
  end
  
  def ssh
    self
  end
  
  def winrm
    self
  end
end