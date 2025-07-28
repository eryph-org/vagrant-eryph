#!/usr/bin/env ruby

require 'fileutils'
require 'yaml'
require 'tmpdir'
require_relative 'support/test_helper'

class VagrantEryphTestRunner
  include TestHelper
  
  def initialize
    @test_results = []
    @failed_tests = []
    @test_start_time = Time.now
    @temp_dirs = []
    
    setup_test_environment
  end
  
  def run_all_tests
    puts "🧪 Starting Vagrant Eryph Plugin Test Suite"
    puts "=" * 60
    
    test_suites = [
      { name: "Plugin Structure", method: :run_structure_tests },
      { name: "Installation", method: :run_installation_tests },
      { name: "Configuration", method: :run_configuration_tests },
      { name: "Unit Tests", method: :run_unit_tests },
      { name: "Integration Tests", method: :run_integration_tests },
      { name: "End-to-End Tests", method: :run_e2e_tests }
    ]
    
    test_suites.each do |suite|
      puts "\n📋 Running #{suite[:name]} Tests..."
      puts "-" * 40
      
      begin
        result = send(suite[:method])
        if result == false
          record_test_failure("#{suite[:name]} Suite", "Some tests in suite failed")
        else
          record_test_result("#{suite[:name]} Suite", true, "All tests passed")
        end
      rescue => e
        record_test_failure("#{suite[:name]} Suite", e.message)
        puts "❌ #{suite[:name]} suite failed: #{e.message}"
      end
    end
    
    generate_test_report
    cleanup_test_environment
    
    exit(@failed_tests.empty? ? 0 : 1)
  end
  
  private
  
  def setup_test_environment
    puts "🔧 Setting up test environment..."
    
    # Ensure test directories exist
    %w[tmp fixtures support mocks].each do |dir|
      FileUtils.mkdir_p("tests/#{dir}")
    end
    
    # Set environment variables for testing
    ENV['VAGRANT_ERYPH_TEST'] = 'true'
    ENV['VAGRANT_ERYPH_DEBUG'] = 'true'
  end
  
  def run_structure_tests
    require_relative 'structure_test'
    StructureTest.new.run_all
  end
  
  def run_installation_tests
    require_relative 'installation_test'
    InstallationTest.new.run_all
  end
  
  def run_configuration_tests
    require_relative 'unit/config_test'
    ConfigTest.new.run_all
  end
  
  def run_unit_tests
    Dir.glob('tests/unit/*_test.rb').each do |test_file|
      require_relative test_file.gsub('tests/', '')
      test_class_name = File.basename(test_file, '.rb').split('_').map(&:capitalize).join
      test_class = Object.const_get(test_class_name)
      test_class.new.run_all if test_class.respond_to?(:new)
    end
  end
  
  def run_integration_tests
    return skip_test_suite("Integration Tests", "Requires Eryph environment") unless eryph_available?
    
    Dir.glob('tests/integration/*_test.rb').each do |test_file|
      require_relative test_file.gsub('tests/', '')
      test_class_name = File.basename(test_file, '.rb').split('_').map(&:capitalize).join
      test_class = Object.const_get(test_class_name)
      test_class.new.run_all if test_class.respond_to?(:new)
    end
  end
  
  def run_e2e_tests
    return skip_test_suite("End-to-End Tests", "Requires Eryph environment") unless eryph_available?
    
    require_relative 'e2e/full_lifecycle_test'
    FullLifecycleTest.new.run_all
  end
  
  def eryph_available?
    # Check if integration is explicitly enabled
    return true if ENV['VAGRANT_ERYPH_INTEGRATION'] == 'true'
    return true if ENV['VAGRANT_ERYPH_MOCK_CLIENT'] == 'true'
    
    # Try to resolve 'zero' configuration for credentials
    begin
      require 'eryph'
      # Simply try to create client with 'zero' config - this will fail if Eryph Zero is not installed/configured
      client = Eryph.compute_client('zero', verify_ssl: false)
      puts "🔍 Successfully resolved 'zero' configuration - Eryph Zero appears to be available"
      return true
    rescue => e
      puts "🔍 Could not resolve 'zero' configuration: #{e.message}" if ENV['VAGRANT_ERYPH_DEBUG']
      return false
    end
  end
  
  def skip_test_suite(name, reason)
    puts "⏭️  Skipping #{name}: #{reason}"
    record_test_result("#{name} (Skipped)", true, reason)
  end
  
  def generate_test_report
    puts "\n" + "=" * 60
    puts "📊 TEST RESULTS SUMMARY"
    puts "=" * 60
    
    total_tests = @test_results.length
    passed_tests = @test_results.count { |result| result[:passed] }
    failed_tests = @failed_tests.length
    
    puts "Total Tests: #{total_tests}"
    puts "Passed: #{passed_tests} ✅"
    puts "Failed: #{failed_tests} ❌"
    puts "Duration: #{(Time.now - @test_start_time).round(2)}s"
    
    if failed_tests > 0
      puts "\n❌ FAILED TESTS:"
      @failed_tests.each do |failure|
        puts "  • #{failure[:test]}: #{failure[:error]}"
      end
    else
      puts "\n🎉 All tests passed!"
    end
    
    # Write detailed report to file
    report_data = {
      'summary' => {
        'total' => total_tests,
        'passed' => passed_tests,
        'failed' => failed_tests,
        'duration' => (Time.now - @test_start_time).round(2),
        'timestamp' => Time.now.iso8601
      },
      'results' => @test_results,
      'failures' => @failed_tests
    }
    
    File.write('tests/tmp/test_report.json', report_data.to_json)
    puts "\n📄 Detailed report saved to: tests/tmp/test_report.json"
  end
  
  def cleanup_test_environment
    @temp_dirs.each do |dir|
      FileUtils.rm_rf(dir) if Dir.exist?(dir)
    end
  end
  
  def record_test_result(test_name, passed, details = nil)
    result = {
      test: test_name,
      passed: passed,
      details: details,
      timestamp: Time.now.iso8601
    }
    @test_results << result
    
    if passed
      puts "✅ #{test_name}"
    else
      puts "❌ #{test_name}: #{details}"
      record_test_failure(test_name, details)
    end
  end
  
  def record_test_failure(test_name, error_message)
    @failed_tests << { test: test_name, error: error_message }
  end
  
  def create_temp_dir(prefix = 'vagrant_eryph_test')
    temp_dir = Dir.mktmpdir(prefix)
    @temp_dirs << temp_dir
    temp_dir
  end
end

# Run tests if this file is executed directly
if __FILE__ == $0
  runner = VagrantEryphTestRunner.new
  runner.run_all_tests
end