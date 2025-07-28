# Basic Windows catlet configuration for testing
Vagrant.configure("2") do |config|
  config.vm.provider :eryph do |eryph|
    eryph.project = "test-basic-windows"
    eryph.parent_gene = "dbosoft/winsrv2022-standard/latest"
    eryph.auto_config = true
    eryph.enable_winrm = true
    eryph.vagrant_password = "TestP@ss123"
    eryph.cpu = 4
    eryph.memory = 4096
  end
  
  # Windows-specific configuration
  config.vm.communicator = "winrm"
  config.winrm.username = "vagrant"
  config.winrm.password = "TestP@ss123"
  config.winrm.port = 5985
  config.winrm.transport = :plaintext
  config.winrm.basic_auth_only = true
  config.vm.guest = :windows
  config.vm.hostname = "basic-win-test"
  
  config.vm.provision "powershell", inline: <<-POWERSHELL
    Write-Host "Basic Windows catlet provisioning test"
    Write-Host "Hostname: $env:COMPUTERNAME"
    Write-Host "User: $env:USERNAME"
    Write-Host "OS: $(Get-ComputerInfo | Select-Object -ExpandProperty WindowsProductName)"
  POWERSHELL
end