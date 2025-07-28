require_relative '../support/test_helper'
require_relative '../mocks/eryph_client_mock'

class WindowsCatletTest
  include TestHelper
  
  def run_all
    puts "🪟 Testing Windows catlet integration..."
    
    tests = [
      :test_windows_server_catlet_creation,
      :test_winrm_connectivity,
      :test_cloud_init_user_setup,
      :test_powershell_execution,
      :test_windows_features_installation,
      :test_administrator_access,
      :test_catlet_lifecycle
    ]
    
    results = tests.map { |test| run_test_method(test.to_s.gsub('test_', ''), method(test)) }
    
    if results.all?
      puts "✅ All Windows catlet tests passed!"
    else
      puts "❌ Some Windows catlet tests failed"
      false
    end
  end
  
  private
  
  def test_windows_server_catlet_creation
    with_temp_dir do |test_dir|
      Dir.chdir(test_dir) do
        # Create Vagrantfile for Windows Server catlet
        create_test_vagrantfile(<<~CONFIG)
          config.vm.provider :eryph do |eryph|
            eryph.project = "windows-test"
            eryph.catlet = {
              parent: "dbosoft/winsrv2022-standard/latest",
              cpu: { count: 4 },
              memory: { startup: 4096 }
            }
            eryph.auto_config = true
            eryph.enable_winrm = true
            eryph.vagrant_password = "TestP@ss123"
          end
          
          config.vm.communicator = "winrm"
          config.winrm.username = "vagrant"
          config.winrm.password = "TestP@ss123"
          config.vm.guest = :windows
        CONFIG
        
        # Test vagrant status recognizes the configuration
        result = capture_output('vagrant status')
        assert(result[:success], "Vagrant status should work: #{result[:output]}")
        
        puts "      Windows Server catlet configuration validated"
      end
    end
    
    true
  end
  
  def test_winrm_connectivity
    return skip_test("Requires running Windows catlet") unless ENV['VAGRANT_ERYPH_INTEGRATION'] == 'true'
    
    with_temp_dir do |test_dir|
      Dir.chdir(test_dir) do
        create_test_vagrantfile(<<~CONFIG)
          config.vm.provider :eryph do |eryph|
            eryph.project = "winrm-test"
            eryph.catlet = {
              parent: "dbosoft/winsrv2022-standard/latest"
            }
            eryph.auto_config = true
            eryph.enable_winrm = true
            eryph.vagrant_password = "TestP@ss123"
          end
          
          config.vm.communicator = "winrm"
          config.winrm.username = "vagrant"
          config.winrm.password = "TestP@ss123"
          config.vm.guest = :windows
        CONFIG
        
        # Start catlet (Windows takes longer to boot)
        result = capture_output('vagrant up --provider=eryph', timeout: 600)
        assert(result[:success], "Should create and start Windows catlet: #{result[:output]}")
        
        # Test WinRM connectivity
        winrm_result = capture_output('vagrant winrm -c "echo \'WinRM connection successful\'"')
        assert(winrm_result[:success], "Should connect via WinRM: #{winrm_result[:output]}")
        assert(winrm_result[:output].include?("WinRM connection successful"), 
               "Should execute commands via WinRM")
        
        # Clean up
        capture_output('vagrant destroy -f')
      end
    end
    
    true
  end
  
  def test_cloud_init_user_setup
    return skip_test("Requires running Windows catlet") unless ENV['VAGRANT_ERYPH_INTEGRATION'] == 'true'
    
    with_temp_dir do |test_dir|
      Dir.chdir(test_dir) do
        create_test_vagrantfile(<<~CONFIG)
          config.vm.provider :eryph do |eryph|
            eryph.project = "user-setup-test"
            eryph.catlet = {
              parent: "dbosoft/winsrv2022-standard/latest"
            }
            eryph.auto_config = true
            eryph.enable_winrm = true
            eryph.vagrant_password = "TestP@ss123"
          end
          
          config.vm.communicator = "winrm"
          config.winrm.username = "vagrant"
          config.winrm.password = "TestP@ss123"
          config.vm.guest = :windows
        CONFIG
        
        # Start catlet
        result = capture_output('vagrant up --provider=eryph', timeout: 600)
        assert(result[:success], "Should create Windows catlet: #{result[:output]}")
        
        # Test that vagrant user exists
        user_check = capture_output('vagrant winrm -c "whoami"')
        assert(user_check[:output].downcase.include?("vagrant"), "Should login as vagrant user")
        
        # Test that vagrant user is in Administrators group
        admin_check = capture_output('vagrant winrm -c "net localgroup administrators"')
        assert(admin_check[:output].downcase.include?("vagrant"), 
               "Vagrant user should be in Administrators group")
        
        # Clean up
        capture_output('vagrant destroy -f')
      end
    end
    
    true
  end
  
  def test_powershell_execution
    return skip_test("Requires running Windows catlet") unless ENV['VAGRANT_ERYPH_INTEGRATION'] == 'true'
    
    with_temp_dir do |test_dir|
      Dir.chdir(test_dir) do
        create_test_vagrantfile(<<~CONFIG)
          config.vm.provider :eryph do |eryph|
            eryph.project = "powershell-test"
            eryph.catlet = {
              parent: "dbosoft/winsrv2022-standard/latest"
            }
            eryph.auto_config = true
            eryph.enable_winrm = true
            eryph.vagrant_password = "TestP@ss123"
          end
          
          config.vm.communicator = "winrm"
          config.winrm.username = "vagrant"
          config.winrm.password = "TestP@ss123"
          config.vm.guest = :windows
        CONFIG
        
        # Start catlet
        result = capture_output('vagrant up --provider=eryph', timeout: 600)
        assert(result[:success], "Should create catlet: #{result[:output]}")
        
        # Test PowerShell execution
        ps_result = capture_output('vagrant winrm -c "Get-ComputerInfo | Select-Object WindowsProductName"')
        assert(ps_result[:success], "Should execute PowerShell commands")
        assert(ps_result[:output].include?("Windows"), "Should return Windows information")
        
        # Test PowerShell version
        version_result = capture_output('vagrant winrm -c "$PSVersionTable.PSVersion.Major"')
        assert(version_result[:success], "Should get PowerShell version")
        
        # Clean up
        capture_output('vagrant destroy -f')
      end
    end
    
    true
  end
  
  def test_windows_features_installation
    return skip_test("Requires running Windows catlet") unless ENV['VAGRANT_ERYPH_INTEGRATION'] == 'true'
    
    with_temp_dir do |test_dir|
      Dir.chdir(test_dir) do
        create_test_vagrantfile(<<~CONFIG)
          config.vm.provider :eryph do |eryph|
            eryph.project = "features-test"
            eryph.catlet = {
              parent: "dbosoft/winsrv2022-standard/latest"
            }
            eryph.auto_config = true
            eryph.enable_winrm = true
            eryph.vagrant_password = "TestP@ss123"
            eryph.fodder = [
              {
                name: "install-iis",
                type: "shellscript",
                content: <<~POWERSHELL
                  #ps1_sysnative
                  Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -All
                  New-Item -Path C:\\iis-installed.txt -ItemType File -Value "IIS installed via cloud-init"
                POWERSHELL
              }
            ]
          end
          
          config.vm.communicator = "winrm"
          config.winrm.username = "vagrant"
          config.winrm.password = "TestP@ss123"
          config.vm.guest = :windows
        CONFIG
        
        # Start catlet
        result = capture_output('vagrant up --provider=eryph', timeout: 600)
        assert(result[:success], "Should create catlet: #{result[:output]}")
        
        # Wait for cloud-init to complete
        sleep 60
        
        # Test that IIS was installed
        iis_check = capture_output('vagrant winrm -c "Get-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole"')
        assert(iis_check[:success], "Should query IIS feature")
        
        # Test that custom file was created
        file_check = capture_output('vagrant winrm -c "Test-Path C:\\iis-installed.txt"')
        assert(file_check[:output].include?("True"), "Custom installation marker should exist")
        
        # Clean up
        capture_output('vagrant destroy -f')
      end
    end
    
    true
  end
  
  def test_administrator_access
    return skip_test("Requires running Windows catlet") unless ENV['VAGRANT_ERYPH_INTEGRATION'] == 'true'
    
    with_temp_dir do |test_dir|
      Dir.chdir(test_dir) do
        create_test_vagrantfile(<<~CONFIG)
          config.vm.provider :eryph do |eryph|
            eryph.project = "admin-test"
            eryph.catlet = {
              parent: "dbosoft/winsrv2022-standard/latest"
            }
            eryph.auto_config = true
            eryph.enable_winrm = true
            eryph.vagrant_password = "TestP@ss123"
          end
          
          config.vm.communicator = "winrm"
          config.winrm.username = "vagrant"
          config.winrm.password = "TestP@ss123"
          config.vm.guest = :windows
        CONFIG
        
        # Start catlet
        result = capture_output('vagrant up --provider=eryph', timeout: 600)
        assert(result[:success], "Should create catlet: #{result[:output]}")
        
        # Test administrative access
        admin_result = capture_output('vagrant winrm -c "([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] \\"Administrator\\")"')
        assert(admin_result[:output].include?("True"), "Should have administrator privileges")
        
        # Test ability to install software (requires admin)
        software_test = capture_output('vagrant winrm -c "choco install -y notepadplusplus"')
        assert(software_test[:success], "Should be able to install software with admin rights")
        
        # Clean up
        capture_output('vagrant destroy -f')
      end
    end
    
    true
  end
  
  def test_catlet_lifecycle
    return skip_test("Requires running Windows catlet") unless ENV['VAGRANT_ERYPH_INTEGRATION'] == 'true'
    
    with_temp_dir do |test_dir|
      Dir.chdir(test_dir) do
        create_test_vagrantfile(<<~CONFIG)
          config.vm.provider :eryph do |eryph|
            eryph.project = "lifecycle-test"
            eryph.catlet = {
              parent: "dbosoft/winsrv2022-standard/latest"
            }
            eryph.auto_config = true
            eryph.enable_winrm = true
            eryph.vagrant_password = "TestP@ss123"
          end
          
          config.vm.communicator = "winrm"
          config.winrm.username = "vagrant"
          config.winrm.password = "TestP@ss123"
          config.vm.guest = :windows
        CONFIG
        
        # Test full lifecycle: up -> halt -> up -> destroy
        # Note: Windows operations are slower
        
        # 1. Create and start
        up_result = capture_output('vagrant up --provider=eryph', timeout: 600)
        assert(up_result[:success], "Should create and start: #{up_result[:output]}")
        
        # 2. Check status
        status_result = capture_output('vagrant status')
        assert(status_result[:output].include?("running"), "Should show running status")
        
        # 3. Halt
        halt_result = capture_output('vagrant halt', timeout: 300)
        assert(halt_result[:success], "Should halt catlet: #{halt_result[:output]}")
        
        # 4. Check stopped status
        status_result = capture_output('vagrant status')
        assert(status_result[:output].include?("stopped"), "Should show stopped status")
        
        # 5. Restart
        up_result = capture_output('vagrant up', timeout: 300)
        assert(up_result[:success], "Should restart catlet: #{up_result[:output]}")
        
        # 6. Destroy
        destroy_result = capture_output('vagrant destroy -f', timeout: 300)
        assert(destroy_result[:success], "Should destroy catlet: #{destroy_result[:output]}")
        
        # 7. Check not created status
        status_result = capture_output('vagrant status')
        assert(status_result[:output].include?("not created"), "Should show not created status")
      end
    end
    
    true
  end
  
  private
  
  def capture_output(command, timeout: 120)
    require 'timeout'
    
    begin
      result = Timeout::timeout(timeout) do
        `#{command} 2>&1`
      end
      { output: result, success: $?.success? }
    rescue Timeout::Error
      { output: "Command timed out after #{timeout} seconds", success: false }
    end
  end
end