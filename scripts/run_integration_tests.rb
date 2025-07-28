#!/usr/bin/env ruby

require 'fileutils'

class IntegrationTestRunner
  def initialize
    @project_root = File.expand_path('..', __dir__)
    @test_results = []
    @failed_tests = []
  end
  
  def run
    puts "🧪 Running Vagrant Eryph Plugin Integration Tests"
    puts "=" * 60
    
    setup_environment
    check_prerequisites
    setup_plugin
    run_tests
    generate_report
    
    exit(@failed_tests.empty? ? 0 : 1)
  end
  
  private
  
  def setup_environment
    puts "\n🔧 Setting up test environment..."
    
    Dir.chdir(@project_root)
    
    # Set integration test environment variables
    ENV['VAGRANT_ERYPH_INTEGRATION'] = 'true'
    ENV['VAGRANT_ERYPH_DEBUG'] = 'true'
    ENV['VAGRANT_LOG'] = 'debug'
    
    puts "  ✅ Environment variables set"
    puts "    VAGRANT_ERYPH_INTEGRATION=#{ENV['VAGRANT_ERYPH_INTEGRATION']}"
    puts "    VAGRANT_ERYPH_DEBUG=#{ENV['VAGRANT_ERYPH_DEBUG']}"
  end
  
  def check_prerequisites
    puts "\n🔍 Checking prerequisites..."
    
    # Check if Vagrant is installed
    vagrant_version = `vagrant --version 2>&1`.strip
    if $?.success?
      puts "  ✅ Vagrant: #{vagrant_version}"
    else
      puts "  ❌ Vagrant not found or not working"
      exit 1
    end
    
    # Check if Eryph-zero is available
    begin
      eryph_version = `eryph-zero --version 2>&1`.strip
      eryph_check = $?.success?
      if eryph_check
        puts "  ✅ Eryph-zero: #{eryph_version}"
      else
        puts "  ⚠️  Eryph-zero command failed - some tests may be skipped"
      end
    rescue
      puts "  ⚠️  Eryph-zero command not found - some tests may be skipped"
    end
    
    # Check if we're on Windows (required for Eryph zero)
    if Gem.win_platform?
      puts "  ✅ Running on Windows (required for Eryph zero)"
    else
      puts "  ⚠️  Not running on Windows - Eryph zero requires Windows with Hyper-V"
    end
  end
  
  def setup_plugin
    puts "\n📦 Setting up plugin..."
    
    # Run the plugin setup script
    setup_script = File.join(@project_root, 'scripts', 'setup_plugin.rb')
    result = system("ruby #{setup_script}")
    
    unless result
      puts "❌ Plugin setup failed!"
      exit 1
    end
    
    puts "  ✅ Plugin setup completed"
  end
  
  def run_tests
    puts "\n🧪 Running integration tests..."
    
    # Force enable integration tests by setting environment variables
    ENV['VAGRANT_ERYPH_INTEGRATION'] = 'true'
    ENV['VAGRANT_ERYPH_DEBUG'] = 'true'
    ENV['VAGRANT_LOG'] = 'debug'
    
    # Use the main test runner with integration enabled
    test_runner_script = File.join(@project_root, 'tests', 'test_runner.rb')
    
    puts "🚀 Running full test suite with integration tests enabled..."
    
    # Capture output and result
    output = `ruby #{test_runner_script} 2>&1`
    success = $?.success?
    
    puts output
    
    if success
      puts "\n✅ Integration test suite completed successfully!"
      record_test_result("Full Integration Suite", true, "All tests completed")
    else
      puts "\n❌ Integration test suite failed!"
      record_test_result("Full Integration Suite", false, "Test suite failed - see output above")
    end
    
    success
  end
  
  def run_test_category(test_category)
    puts "\n📋 Running #{test_category[:name]}..."
    puts "-" * 40
    
    script_path = File.join(@project_root, test_category[:script])
    
    unless File.exist?(script_path)
      record_test_result(test_category[:name], false, "Test file not found: #{script_path}")
      return
    end
    
    begin
      # Capture output and result
      output = `ruby #{script_path} 2>&1`
      success = $?.success?
      
      if success
        puts "✅ #{test_category[:name]} - PASSED"
        record_test_result(test_category[:name], true, "All tests passed")
      else
        puts "❌ #{test_category[:name]} - FAILED"
        puts "Output:"
        puts output.split("\n").map { |line| "  #{line}" }.join("\n")
        record_test_result(test_category[:name], false, "Tests failed - see output")
        
        if test_category[:required]
          puts "\n⚠️  This is a required test category - continuing with other tests but will report failure"
        end
      end
      
    rescue => e
      puts "❌ #{test_category[:name]} - ERROR"
      puts "  Error: #{e.message}"
      record_test_result(test_category[:name], false, "Test execution error: #{e.message}")
    end
  end
  
  def generate_report
    puts "\n" + "=" * 60
    puts "📊 INTEGRATION TEST RESULTS SUMMARY"
    puts "=" * 60
    
    total_tests = @test_results.length
    passed_tests = @test_results.count { |result| result[:passed] }
    failed_tests = @failed_tests.length
    
    puts "Total Test Categories: #{total_tests}"
    puts "Passed: #{passed_tests} ✅"
    puts "Failed: #{failed_tests} ❌"
    
    if failed_tests > 0
      puts "\n❌ FAILED TESTS:"
      @failed_tests.each do |failure|
        puts "  • #{failure[:test]}: #{failure[:error]}"
      end
      
      puts "\n💡 TROUBLESHOOTING TIPS:"
      puts "  - Ensure Eryph is running and accessible"
      puts "  - Check if you have sufficient permissions for Hyper-V"
      puts "  - Verify network connectivity to Eryph API"
      puts "  - Check Windows Hyper-V is enabled"
      puts "  - Ensure no other VM software conflicts"
    else
      puts "\n🎉 All integration tests passed!"
    end
    
    # Write detailed report
    report_data = {
      'summary' => {
        'total' => total_tests,
        'passed' => passed_tests, 
        'failed' => failed_tests,
        'timestamp' => Time.now.iso8601
      },
      'results' => @test_results,
      'failures' => @failed_tests,
      'environment' => {
        'vagrant_version' => `vagrant --version 2>&1`.strip,
        'eryph_available' => begin; `eryph-zero --version 2>&1`; $?.success?; rescue; false; end,
        'windows_platform' => Gem.win_platform?,
        'integration_mode' => ENV['VAGRANT_ERYPH_INTEGRATION']
      }
    }
    
    FileUtils.mkdir_p('tests/tmp')
    File.write('tests/tmp/integration_test_report.json', JSON.pretty_generate(report_data))
    puts "\n📄 Detailed report saved to: tests/tmp/integration_test_report.json"
  end
  
  def record_test_result(test_name, passed, details = nil)
    result = {
      test: test_name,
      passed: passed,
      details: details,
      timestamp: Time.now.iso8601
    }
    @test_results << result
    
    unless passed
      record_test_failure(test_name, details)
    end
  end
  
  def record_test_failure(test_name, error_message)
    @failed_tests << { test: test_name, error: error_message }
  end
end

# Run integration tests if this file is executed directly
if __FILE__ == $0
  require 'json'
  
  begin
    runner = IntegrationTestRunner.new
    runner.run
  rescue => e
    puts "\n❌ Integration test runner failed: #{e.message}"
    puts "\nStacktrace:"
    puts e.backtrace.join("\n")
    exit 1
  end
end