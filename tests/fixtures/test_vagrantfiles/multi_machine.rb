# Multi-machine configuration with Linux and Windows catlets
Vagrant.configure("2") do |config|
  # Linux web server
  config.vm.define "web" do |web|
    web.vm.provider :eryph do |eryph|
      eryph.project = "test-multi-machine"
      eryph.parent_gene = "dbosoft/ubuntu-22.04/latest"
      eryph.auto_config = true
      eryph.cpu = 2
      eryph.memory = 2048
      
      # Install web server components
      eryph.fodder = [
        {
          name: "web-server-setup",
          type: "cloud-config",
          content: {
            "packages" => ["nginx", "nodejs", "npm"],
            "runcmd" => [
              "systemctl enable nginx",
              "systemctl start nginx",
              "echo '<h1>Eryph Web Server</h1><p>Running on Linux catlet</p>' > /var/www/html/index.html",
              "echo 'Web server setup completed' >> /var/log/web-setup.log"
            ]
          }
        }
      ]
    end
    
    web.vm.hostname = "web-server"
    
    web.vm.provision "shell", inline: <<-SHELL
      echo "=== Web Server Configuration ==="
      nginx -v
      systemctl status nginx --no-pager
      curl -s http://localhost | head -5
    SHELL
  end
  
  # Windows database server
  config.vm.define "db" do |db|
    db.vm.provider :eryph do |eryph|
      eryph.project = "test-multi-machine"
      eryph.parent_gene = "dbosoft/winsrv2022-standard/latest"
      eryph.auto_config = true
      eryph.enable_winrm = true
      eryph.vagrant_password = "DbP@ss123"
      eryph.cpu = 4
      eryph.memory = 4096
      
      # Install SQL Server Express
      eryph.fodder = [
        {
          name: "sql-server-setup",
          type: "shellscript",
          content: <<~POWERSHELL
            #ps1_sysnative
            Write-Host "Installing SQL Server Express..."
            
            # Install Chocolatey first
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            
            # Install SQL Server Express
            choco install -y sql-server-express
            
            # Install SQL Server Management Studio
            choco install -y sql-server-management-studio
            
            Write-Host "SQL Server setup completed"
            
            # Create a marker file
            New-Item -Path "C:\\sql-server-installed.txt" -ItemType File -Value "SQL Server installed via cloud-init"
          POWERSHELL
        }
      ]
    end
    
    # Windows-specific configuration
    db.vm.communicator = "winrm"
    db.winrm.username = "vagrant"
    db.winrm.password = "DbP@ss123"
    db.winrm.port = 5985
    db.winrm.transport = :plaintext
    db.winrm.basic_auth_only = true
    db.vm.guest = :windows
    db.vm.hostname = "db-server"
    
    db.vm.provision "powershell", inline: <<-POWERSHELL
      Write-Host "=== Database Server Configuration ===" -ForegroundColor Yellow
      
      # Check SQL Server installation
      Write-Host "Checking SQL Server installation..." -ForegroundColor Cyan
      if (Test-Path "C:\\sql-server-installed.txt") {
          Write-Host "SQL Server installation marker found" -ForegroundColor Green
          Get-Content "C:\\sql-server-installed.txt"
      } else {
          Write-Host "SQL Server installation marker not found" -ForegroundColor Red
      }
      
      # Check SQL Server services
      Write-Host "Checking SQL Server services..." -ForegroundColor Cyan
      Get-Service | Where-Object {$_.Name -like "*SQL*"} | Select-Object Name, Status
      
      Write-Host "Database server configuration completed" -ForegroundColor Green
    POWERSHELL
  end
  
  # Load balancer (Linux)
  config.vm.define "lb" do |lb|
    lb.vm.provider :eryph do |eryph|
      eryph.project = "test-multi-machine"
      eryph.parent_gene = "dbosoft/ubuntu-22.04/latest"
      eryph.auto_config = true
      eryph.cpu = 1
      eryph.memory = 1024
      
      # Install HAProxy
      eryph.fodder = [
        {
          name: "haproxy-setup",
          type: "cloud-config",
          content: {
            "packages" => ["haproxy"],
            "write_files" => [
              {
                "path" => "/etc/haproxy/haproxy.cfg",
                "content" => <<~HAPROXY
                  global
                      daemon
                  
                  defaults
                      mode http
                      timeout connect 5000ms
                      timeout client 50000ms
                      timeout server 50000ms
                  
                  frontend web_frontend
                      bind *:80
                      default_backend web_servers
                  
                  backend web_servers
                      balance roundrobin
                      server web1 192.168.1.100:80 check
                      # Add more web servers as needed
                  
                  listen stats
                      bind *:8080
                      stats enable
                      stats uri /stats
                HAPROXY
                ,
                "owner" => "root:root",
                "permissions" => "0644"
              }
            ],
            "runcmd" => [
              "systemctl enable haproxy",
              "systemctl start haproxy",
              "echo 'Load balancer setup completed' >> /var/log/lb-setup.log"
            ]
          }
        }
      ]
    end
    
    lb.vm.hostname = "load-balancer"
    
    lb.vm.provision "shell", inline: <<-SHELL
      echo "=== Load Balancer Configuration ==="
      haproxy -v
      systemctl status haproxy --no-pager
      netstat -tlnp | grep :80
      netstat -tlnp | grep :8080
      echo "Load balancer configured for high availability"
    SHELL
  end
end