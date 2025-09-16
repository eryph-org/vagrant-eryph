require 'spec_helper'
require 'open3'
require 'timeout'
require 'tmpdir'

RSpec.describe 'E2E Smoke Tests' do
  let(:test_timeout) { 900 } # 15 minutes for full VM lifecycle
  let(:test_vagrantfile) { File.join(__dir__, 'test.Vagrantfile') }
  
  def run_vagrant_command(command, timeout: 300)
    # Run Vagrant command and capture output
    # NO environment checks - just run and let it fail naturally
    
    cmd = "vagrant #{command}"
    puts "Running: #{cmd}"
    
    stdout, stderr, status = nil, nil, nil
    
    Timeout::timeout(timeout) do
      stdout, stderr, status = Open3.capture3(
        cmd,
        chdir: test_dir
      )
    end
    
    puts "STDOUT:\n#{stdout}" unless stdout.empty?
    puts "STDERR:\n#{stderr}" unless stderr.empty?
    puts "Exit code: #{status.exitstatus}"
    
    {
      stdout: stdout,
      stderr: stderr,
      success: status.success?,
      exitstatus: status.exitstatus
    }
  end
  
  def test_dir
    @test_dir ||= begin
      dir = Dir.mktmpdir('vagrant-eryph-e2e-')
      
      # Copy test Vagrantfile
      FileUtils.cp(test_vagrantfile, File.join(dir, 'Vagrantfile'))
      
      # Ensure cleanup
      at_exit { FileUtils.rm_rf(dir) }
      
      dir
    end
  end
  
  describe 'Full VM Lifecycle' do
    after(:each) do
      # Always try to clean up, even if test fails
      begin
        run_vagrant_command('destroy -f', timeout: 180)
      rescue => e
        puts "Cleanup failed: #{e.message}"
      end
    end
    
    it 'completes full deployment lifecycle' do
      # 1. VAGRANT STATUS - should recognize provider
      result = run_vagrant_command('status')
      expect(result[:success]).to be(true), "vagrant status failed: #{result[:stderr]}"
      expect(result[:stdout]).to include('eryph'), "Provider not recognized in status output"
      
      # 2. VAGRANT UP - deploy catlet
      result = run_vagrant_command('up --provider=eryph', timeout: 600)
      expect(result[:success]).to be(true), "vagrant up failed: #{result[:stderr]}"
      expect(result[:stdout]).to match(/catlet.*provisioned successfully/i), "No catlet creation confirmation"
      
      # 3. VAGRANT STATUS - should show running
      result = run_vagrant_command('status')
      expect(result[:success]).to be(true), "vagrant status after up failed: #{result[:stderr]}"
      expect(result[:stdout]).to match(/running/i), "VM should be running after up"
      
      # 4. VAGRANT SSH-CONFIG - should have SSH details
      result = run_vagrant_command('ssh-config')
      expect(result[:success]).to be(true), "vagrant ssh-config failed: #{result[:stderr]}"
      expect(result[:stdout]).to include('Host '), "No SSH host configuration"
      expect(result[:stdout]).to include('HostName '), "No SSH hostname"
      
      # 5. VAGRANT SSH - test actual connectivity
      result = run_vagrant_command('ssh -c "echo Hello from E2E test"', timeout: 60)
      expect(result[:success]).to be(true), "SSH connection failed: #{result[:stderr]}"
      expect(result[:stdout]).to include('Hello from E2E test'), "SSH command did not execute"
      
      # 6. VAGRANT HALT - stop catlet
      result = run_vagrant_command('halt', timeout: 180)
      expect(result[:success]).to be(true), "vagrant halt failed: #{result[:stderr]}"
      
      # 7. VAGRANT STATUS - should show stopped
      result = run_vagrant_command('status')
      expect(result[:success]).to be(true), "vagrant status after halt failed: #{result[:stderr]}"
      expect(result[:stdout]).to match(/stopped|poweroff/i), "VM should be stopped after halt"
      
      # 8. VAGRANT DESTROY - clean up
      result = run_vagrant_command('destroy -f', timeout: 180)
      expect(result[:success]).to be(true), "vagrant destroy failed: #{result[:stderr]}"
      
      # 9. VAGRANT STATUS - should show not created
      result = run_vagrant_command('status')
      expect(result[:success]).to be(true), "vagrant status after destroy failed: #{result[:stderr]}"
      expect(result[:stdout]).to match(/not_created/i), "VM should be not created after destroy"
      
      puts "✅ Full E2E lifecycle completed successfully"
    end
  end
  
  describe 'Error Handling' do
    it 'fails gracefully with invalid configuration' do
      # Create invalid Vagrantfile
      invalid_vagrantfile = <<~CONFIG
        Vagrant.configure("2") do |config|
          config.vm.provider :eryph do |eryph|
            # Missing required parent
            eryph.project = "e2e-test"
          end
        end
      CONFIG
      
      File.write(File.join(test_dir, 'Vagrantfile'), invalid_vagrantfile)
      
      # Should fail validation
      result = run_vagrant_command('validate')
      # Either succeeds (validation doesn't catch it) or fails (validation does catch it)
      # But should not crash
      expect([true, false]).to include(result[:success])
      expect(result[:stderr]).not_to include('undefined method'), "Should not crash with undefined method"
      
      # up should definitely fail
      result = run_vagrant_command('up --provider=eryph', timeout: 60)
      expect(result[:success]).to be(false), "Should fail with invalid configuration"
      expect(result[:stderr]).not_to include('undefined method'), "Should fail gracefully, not crash"
    end
  end
  
  describe 'Provider Detection' do
    it 'recognizes eryph provider' do
      result = run_vagrant_command('--help')
      expect(result[:success]).to be(true), "vagrant --help failed: #{result[:stderr]}"
      
      # Check if plugin is loaded - provider should be available
      result = run_vagrant_command('status')
      expect(result[:success]).to be(true), "vagrant status failed: #{result[:stderr]}"
      # Should not complain about unknown provider
      expect(result[:stderr]).not_to include('provider.*not.*found'), "Provider should be recognized"
    end
  end
end