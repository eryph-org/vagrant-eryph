require 'json'
require 'fileutils'
require 'tempfile'
require 'tmpdir'
require_relative 'vagrant_mock'

module TestHelper
  def assert(condition, message = "Assertion failed")
    unless condition
      raise AssertionError, message
    end
    true
  end
  
  def assert_equal(expected, actual, message = nil)
    message ||= "Expected #{expected.inspect}, got #{actual.inspect}"
    assert(expected == actual, message)
  end
  
  def assert_not_nil(value, message = "Expected value to not be nil")
    assert(!value.nil?, message)
  end
  
  def assert_nil(value, message = "Expected value to be nil")
    assert(value.nil?, message)
  end
  
  def assert_file_exists(path, message = nil)
    message ||= "Expected file #{path} to exist"
    assert(File.exist?(path), message)
  end
  
  def assert_file_contains(path, content, message = nil)
    assert_file_exists(path)
    
    # Try multiple methods to read the file
    file_content = nil
    begin
      file_content = File.read(path)
    rescue => e
      # Try with absolute path
      abs_path = File.expand_path(path)
      file_content = File.read(abs_path)
    end
    
    # Fallback if content is empty
    if file_content.length == 0
      # Try IO.read as fallback
      begin
        file_content = IO.read(path)
      rescue => e
        # Last resort - try with explicit encoding
        file_content = File.read(path, encoding: 'UTF-8')
      end
    end
    
    message ||= "Expected file #{path} to contain '#{content}'"
    assert(file_content.include?(content), message)
  end
  
  def assert_command_success(command, message = nil)
    result = system(command)
    message ||= "Expected command '#{command}' to succeed"
    assert(result, message)
  end
  
  def capture_output(command, timeout: nil)
    if timeout
      require 'timeout'
      begin
        result = Timeout::timeout(timeout) do
          `#{command} 2>&1`
        end
        { output: result, success: $?.success? }
      rescue Timeout::Error
        { output: "Command timed out after #{timeout} seconds", success: false }
      end
    else
      result = `#{command} 2>&1`
      { output: result, success: $?.success? }
    end
  end
  
  def with_temp_file(content = "", extension = ".tmp")
    file = Tempfile.new(["test", extension])
    file.write(content)
    file.close
    
    begin
      yield file.path
    ensure
      file.unlink
    end
  end
  
  def with_temp_dir(prefix = "test")
    dir = Dir.mktmpdir(prefix)
    begin
      yield dir
    ensure
      FileUtils.rm_rf(dir)
    end
  end
  
  def mock_vagrant_environment(box_name = "test-box")
    {
      'VAGRANT_CWD' => Dir.pwd,
      'VAGRANT_DEFAULT_PROVIDER' => 'eryph',
      'VAGRANT_BOX_NAME' => box_name
    }
  end
  
  def create_test_vagrantfile(config_block, path = 'Vagrantfile')
    content = <<~RUBY
      Vagrant.configure("2") do |config|
        #{config_block}
      end
    RUBY
    
    File.write(path, content)
    path
  end
  
  def run_test_method(method_name, method_proc = nil, &block)
    test_block = block || method_proc
    begin
      puts "  🧪 #{method_name}"
      test_block.call
      puts "    ✅ Passed"
      true
    rescue => e
      puts "    ❌ Failed: #{e.message}"
      false
    end
  end
  
  def skip_test(reason)
    puts "    ⏭️  Skipped: #{reason}"
    true
  end
  
  class AssertionError < StandardError; end
end