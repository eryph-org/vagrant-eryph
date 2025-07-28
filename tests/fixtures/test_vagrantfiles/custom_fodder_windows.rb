# Windows catlet with custom cloud-init fodder
Vagrant.configure("2") do |config|
  config.vm.provider :eryph do |eryph|
    eryph.project = "test-custom-windows"
    eryph.parent_gene = "dbosoft/winsrv2022-standard/latest"
    eryph.auto_config = true
    eryph.enable_winrm = true
    eryph.vagrant_password = "DevP@ss123"
    eryph.cpu = 4
    eryph.memory = 6144
    
    # Custom Windows setup with development tools
    eryph.fodder = [
      {
        name: "chocolatey-setup",
        type: "shellscript",
        content: <<~POWERSHELL
          #ps1_sysnative
          Write-Host "Installing Chocolatey package manager..."
          Set-ExecutionPolicy Bypass -Scope Process -Force
          [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
          iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
          
          Write-Host "Chocolatey installation completed"
          choco --version
        POWERSHELL
      },
      {
        name: "development-tools",
        type: "shellscript", 
        content: <<~POWERSHELL
          #ps1_sysnative
          Write-Host "Installing development tools via Chocolatey..."
          
          # Install development tools
          choco install -y git
          choco install -y vscode
          choco install -y nodejs
          choco install -y python3
          choco install -y dotnet-sdk
          choco install -y docker-desktop
          choco install -y notepadplusplus
          choco install -y 7zip
          choco install -y googlechrome
          
          Write-Host "Development tools installation completed"
          
          # Refresh environment variables
          refreshenv
          
          # Create development directory
          New-Item -Path "C:\\Development" -ItemType Directory -Force
          New-Item -Path "C:\\Development\\Projects" -ItemType Directory -Force
          
          # Set up Git global configuration
          git config --global user.name "Vagrant User"
          git config --global user.email "vagrant@eryph.local"
          
          Write-Host "Development environment setup completed"
        POWERSHELL
      },
      {
        name: "iis-setup",
        type: "shellscript",
        content: <<~POWERSHELL
          #ps1_sysnative
          Write-Host "Installing and configuring IIS..."
          
          # Install IIS with common features
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -All
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServer -All
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-CommonHttpFeatures -All
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpErrors -All
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpLogging -All
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-StaticContent -All
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-DefaultDocument -All
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-DirectoryBrowsing -All
          Enable-WindowsOptionalFeature -Online -FeatureName IIS-ASPNET45 -All
          
          # Create a simple test page
          $testPageContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Eryph Windows Development Server</title>
</head>
<body>
    <h1>Welcome to Eryph Windows Development Environment</h1>
    <p>This server was configured via Vagrant and cloud-init.</p>
    <p>Server Name: $env:COMPUTERNAME</p>
    <p>Current Time: $(Get-Date)</p>
</body>
</html>
"@
          
          $testPageContent | Out-File -FilePath "C:\\inetpub\\wwwroot\\index.html" -Encoding UTF8
          
          Write-Host "IIS setup completed"
        POWERSHELL
      },
      {
        name: "powershell-profile",
        type: "shellscript",
        content: <<~POWERSHELL
          #ps1_sysnative
          Write-Host "Setting up PowerShell profile..."
          
          # Create PowerShell profile directory
          $profileDir = Split-Path $PROFILE -Parent
          if (!(Test-Path $profileDir)) {
              New-Item -Path $profileDir -ItemType Directory -Force
          }
          
          # Create custom PowerShell profile
          $profileContent = @"
# Custom PowerShell Profile for Development
Write-Host "Loading development PowerShell profile..." -ForegroundColor Green

# Set up aliases
Set-Alias -Name ll -Value Get-ChildItem
Set-Alias -Name grep -Value Select-String
Set-Alias -Name which -Value Get-Command

# Custom functions
function Get-GitStatus { git status }
Set-Alias -Name gs -Value Get-GitStatus

function New-Directory {
    param([string]`$Path)
    New-Item -Path `$Path -ItemType Directory -Force
}
Set-Alias -Name mkdir -Value New-Directory

# Set location to development directory
Set-Location C:\\Development

Write-Host "Development environment ready!" -ForegroundColor Yellow
Write-Host "Available tools: git, node, python, dotnet, docker" -ForegroundColor Cyan
"@
          
          $profileContent | Out-File -FilePath $PROFILE -Encoding UTF8
          
          Write-Host "PowerShell profile created at: $PROFILE"
        POWERSHELL
      }
    ]
  end
  
  # Windows-specific configuration
  config.vm.communicator = "winrm"
  config.winrm.username = "vagrant"
  config.winrm.password = "DevP@ss123"
  config.winrm.port = 5985
  config.winrm.transport = :plaintext
  config.winrm.basic_auth_only = true
  config.vm.guest = :windows
  config.vm.hostname = "dev-win-server"
  
  # Test provisioning that validates our custom setup
  config.vm.provision "powershell", inline: <<-POWERSHELL
    Write-Host "=== Validating Windows Development Environment ===" -ForegroundColor Yellow
    
    # Check Chocolatey
    Write-Host "Checking Chocolatey installation..." -ForegroundColor Cyan
    choco --version
    
    # Check installed packages
    Write-Host "Checking installed development tools..." -ForegroundColor Cyan
    choco list --local-only | Select-String "(git|vscode|nodejs|python|dotnet)"
    
    # Check Git configuration
    Write-Host "Checking Git configuration..." -ForegroundColor Cyan
    git config --global --list
    
    # Check development directories
    Write-Host "Checking development directories..." -ForegroundColor Cyan
    if (Test-Path "C:\\Development\\Projects") {
        Write-Host "Development directories created successfully" -ForegroundColor Green
        Get-ChildItem "C:\\Development" -Force
    } else {
        Write-Host "Development directories missing" -ForegroundColor Red
    }
    
    # Check IIS
    Write-Host "Checking IIS installation..." -ForegroundColor Cyan
    Get-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole | Select-Object State
    
    # Check PowerShell profile
    Write-Host "Checking PowerShell profile..." -ForegroundColor Cyan
    if (Test-Path $PROFILE) {
        Write-Host "PowerShell profile created successfully" -ForegroundColor Green
    } else {
        Write-Host "PowerShell profile missing" -ForegroundColor Red
    }
    
    Write-Host "=== Windows Development Environment Validation Complete ===" -ForegroundColor Yellow
  POWERSHELL
end