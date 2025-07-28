require 'spec_helper'

RSpec.describe "Windows Catlet Integration", type: :integration do
  before(:each) do
    skip_unless_integration_tests
    expect_plugin_installed
  end

  describe "Windows Server catlet creation" do
    it "creates and configures a Windows Server catlet successfully" do
      with_temp_dir do |test_dir|
        # Create Vagrantfile with Windows catlet configuration
        create_test_vagrantfile(<<~CONFIG)
          config.vm.provider :eryph do |eryph|
            eryph.project = "rspec-windows-test"
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

        # Test vagrant status works
        status_result = execute_vagrant_command('status')
        expect(status_result[:success]).to be true
        expect(status_result[:output]).not_to include("could not be found")
      end
    end
  end

  describe "WinRM connectivity", :slow do
    it "establishes WinRM connection to Windows catlet" do
      with_temp_dir do |test_dir|
        Dir.chdir(test_dir) do
          create_test_vagrantfile(<<~CONFIG)
            config.vm.provider :eryph do |eryph|
              eryph.project = "rspec-winrm-test"
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
          up_result = capture_vagrant_output('vagrant up --provider=eryph', timeout: 600)
          
          if up_result[:success]
            # Test WinRM connectivity
            winrm_result = capture_vagrant_output('vagrant winrm -c "echo \'WinRM connection successful\'"')
            expect(winrm_result[:success]).to be true
            expect(winrm_result[:output]).to include("WinRM connection successful")

            # Clean up
            capture_vagrant_output('vagrant destroy -f')
          else
            if up_result[:output].include?("could not be found, but was requested")
              fail "vagrant-eryph plugin not properly installed"
            elsif up_result[:output].include?("Could not resolve") || up_result[:output].include?("No client configuration")
              skip "Eryph client configuration not available for integration testing"
            else
              fail "Unexpected vagrant up failure: #{up_result[:output]}"
            end
          end
        end
      end
    end
  end

  describe "cloud-init user setup", :slow do
    it "creates vagrant user with proper permissions on Windows" do
      with_temp_dir do |test_dir|
        Dir.chdir(test_dir) do
          create_test_vagrantfile(<<~CONFIG)
            config.vm.provider :eryph do |eryph|
              eryph.project = "rspec-user-setup-test"
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
          up_result = capture_vagrant_output('vagrant up --provider=eryph', timeout: 600)
          expect(up_result[:success]).to be true

          # Test that vagrant user exists
          user_check = capture_vagrant_output('vagrant winrm -c "whoami"')
          expect(user_check[:output].downcase).to include("vagrant")

          # Test that vagrant user is in Administrators group
          admin_check = capture_vagrant_output('vagrant winrm -c "net localgroup administrators"')
          expect(admin_check[:output].downcase).to include("vagrant")

          # Clean up
          capture_vagrant_output('vagrant destroy -f')
        end
      end
    end
  end

  describe "PowerShell execution", :slow do
    it "executes PowerShell commands successfully" do
      with_temp_dir do |test_dir|
        Dir.chdir(test_dir) do
          create_test_vagrantfile(<<~CONFIG)
            config.vm.provider :eryph do |eryph|
              eryph.project = "rspec-powershell-test"
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
          up_result = capture_vagrant_output('vagrant up --provider=eryph', timeout: 600)
          expect(up_result[:success]).to be true

          # Test PowerShell execution
          ps_result = capture_vagrant_output('vagrant winrm -c "Get-ComputerInfo | Select-Object WindowsProductName"')
          expect(ps_result[:success]).to be true
          expect(ps_result[:output]).to include("Windows")

          # Test PowerShell version
          version_result = capture_vagrant_output('vagrant winrm -c "$PSVersionTable.PSVersion.Major"')
          expect(version_result[:success]).to be true

          # Clean up
          capture_vagrant_output('vagrant destroy -f')
        end
      end
    end
  end

  describe "Windows features installation", :slow do
    it "installs Windows features via cloud-init" do
      with_temp_dir do |test_dir|
        Dir.chdir(test_dir) do
          create_test_vagrantfile(<<~CONFIG)
            config.vm.provider :eryph do |eryph|
              eryph.project = "rspec-features-test"
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
                    New-Item -Path C:\\\\iis-installed.txt -ItemType File -Value "IIS installed via cloud-init"
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
          up_result = capture_vagrant_output('vagrant up --provider=eryph', timeout: 600)
          expect(up_result[:success]).to be true

          # Wait for cloud-init to complete
          sleep 60

          # Test that IIS was installed
          iis_check = capture_vagrant_output('vagrant winrm -c "Get-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole"')
          expect(iis_check[:success]).to be true

          # Test that custom file was created
          file_check = capture_vagrant_output('vagrant winrm -c "Test-Path C:\\\\iis-installed.txt"')
          expect(file_check[:output]).to include("True")

          # Clean up
          capture_vagrant_output('vagrant destroy -f')
        end
      end
    end
  end

  describe "administrator access", :slow do
    it "grants administrator privileges to vagrant user" do
      with_temp_dir do |test_dir|
        Dir.chdir(test_dir) do
          create_test_vagrantfile(<<~CONFIG)
            config.vm.provider :eryph do |eryph|
              eryph.project = "rspec-admin-test"
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
          up_result = capture_vagrant_output('vagrant up --provider=eryph', timeout: 600)
          expect(up_result[:success]).to be true

          # Test administrative access
          admin_result = capture_vagrant_output('vagrant winrm -c "([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] \\"Administrator\\")"')
          expect(admin_result[:output]).to include("True")

          # Clean up
          capture_vagrant_output('vagrant destroy -f')
        end
      end
    end
  end

  describe "catlet lifecycle", :slow do
    it "supports full create -> halt -> start -> destroy lifecycle on Windows" do
      with_temp_dir do |test_dir|
        Dir.chdir(test_dir) do
          create_test_vagrantfile(<<~CONFIG)
            config.vm.provider :eryph do |eryph|
              eryph.project = "rspec-lifecycle-test"
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

          # 1. Create and start
          up_result = capture_vagrant_output('vagrant up --provider=eryph', timeout: 600)
          expect(up_result[:success]).to be true

          # 2. Check status
          status_result = capture_vagrant_output('vagrant status')
          expect(status_result[:output]).to include("running")

          # 3. Halt
          halt_result = capture_vagrant_output('vagrant halt', timeout: 300)
          expect(halt_result[:success]).to be true

          # 4. Check stopped status
          status_result = capture_vagrant_output('vagrant status')
          expect(status_result[:output]).to include("stopped")

          # 5. Restart
          up_result = capture_vagrant_output('vagrant up', timeout: 300)
          expect(up_result[:success]).to be true

          # 6. Destroy
          destroy_result = capture_vagrant_output('vagrant destroy -f', timeout: 300)
          expect(destroy_result[:success]).to be true

          # 7. Check not created status
          status_result = capture_vagrant_output('vagrant status')
          expect(status_result[:output]).to include("not created")
        end
      end
    end
  end
end