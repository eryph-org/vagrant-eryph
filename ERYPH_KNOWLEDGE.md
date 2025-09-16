# Eryph Knowledge Base

This knowledge base contains essential information about Eryph for the Vagrant plugin development and usage. It serves as a reference for understanding Eryph concepts, APIs, and best practices.

## Table of Contents

- [Core Concepts](#core-concepts)
- [Architecture Overview](#architecture-overview)
- [API Reference](#api-reference)
- [Configuration Patterns](#configuration-patterns)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Testing Guidelines](#testing-guidelines)

## Core Concepts

### Catlets
**Catlets** are Eryph's virtual machines - lightweight, containerized VMs that provide standardized machine builds and configurations.

- **Purpose**: Standardize machine deployments across environments
- **Features**: Fast provisioning, configuration management, snapshot support
- **Lifecycle**: Create → Start → Stop → Destroy
- **State Management**: Running, Stopped, Creating, Destroying

### Genes and Genesets
**Genes** are packages that contain VM artifacts and configurations.

- **Gene Format**: `organization/name:version` (e.g., `dbosoft/ubuntu-22.04:latest`)
- **Geneset**: Collection of genes that define a complete environment
- **Common Catlets** (from genepool):
  - `dbosoft/ubuntu-22.04/latest` - Ubuntu 22.04 LTS
  - `dbosoft/winsrv2022-standard/latest` - Windows Server 2022

### Projects
**Projects** organize catlets and resources within Eryph.

- **Scope**: Logical grouping of related catlets
- **Access Control**: Project-based permissions and resource limits
- **Auto-creation**: Can be automatically created if missing

### Fodder (Cloud-init)
**Fodder** is Eryph's term for cloud-init configuration data.

- **Types**: 
  - `cloud-config` - YAML-based configuration
  - `shellscript` - Shell scripts for Linux
  - `powershell` - PowerShell scripts for Windows (use `#ps1_sysnative` directive)
- **Merging**: Multiple fodder items are processed in order
- **Auto-generation**: Vagrant plugin automatically generates user setup fodder

## Architecture Overview

### Eryph Zero
Current standalone version that runs on Windows with Hyper-V:

- **Host Requirements**: Windows 10/11 Pro or Windows Server with Hyper-V
- **Networking**: Virtual IP networking with automatic IP assignment
- **Storage**: Dynamic storage allocation and management
- **API**: REST API for programmatic access

### Component Stack
```
┌─────────────────────────────────────┐
│            Applications             │  (Vagrant Plugin, PowerShell Module)
├─────────────────────────────────────┤
│              Eryph API              │  (REST API, Authentication)
├─────────────────────────────────────┤
│            Eryph Engine             │  (Catlet Management, Networking)
├─────────────────────────────────────┤
│             Hyper-V                 │  (Virtualization Platform)
├─────────────────────────────────────┤
│             Windows OS              │  (Host Operating System)
└─────────────────────────────────────┘
```

### Networking Model
- **Virtual Networks**: Isolated network segments for catlets
- **IP Management**: Automatic IP address assignment within networks
- **Cross-platform**: Linux and Windows catlets on same networks
- **Port Forwarding**: Configurable port mappings to host

## API Reference

### Authentication
```powershell
# Credential lookup order:
# 1. Local scope (current directory)
# 2. User scope (user profile)
# 3. Global scope (system-wide)
```

### Core Operations

#### Project Management
```ruby
# List projects
client.list_projects()

# Get specific project
client.get_project(name)

# Create project
client.create_project(name: "project-name", description: "Description")

# Delete project
client.delete_project(name)
```

#### Catlet Management
```ruby
# List catlets
client.list_catlets(project_name)

# Get catlet details
client.get_catlet(catlet_id)

# Create catlet
client.create_catlet({
  name: "catlet-name",
  project: "project-name",
  parent: "dbosoft/ubuntu-22.04/latest",
  cpu: 2,
  memory: 2048,
  drives: [...],
  networks: [...],
  fodder: [...]
})

# Control catlet
client.start_catlet(catlet_id)
client.stop_catlet(catlet_id)
client.delete_catlet(catlet_id)
```

#### Operation Monitoring
```ruby
# Get operation status
operation = client.get_operation(operation_id)

# Wait for completion
client.wait_for_operation(operation_id, timeout: 300)
```

### Error Handling
Common error scenarios:
- **Network connectivity issues**: Check Eryph service status
- **Authentication failures**: Verify credential configuration
- **Resource limits**: Check available CPU/memory quotas
- **Gene not found**: Verify gene name and availability

## Configuration Patterns

### Basic Linux Catlet
```ruby
config.vm.provider :eryph do |eryph|
  eryph.project = "development"
  eryph.parent = "dbosoft/ubuntu-22.04/latest"
  eryph.auto_config = true
  eryph.cpu = 2
  eryph.memory = 2048
end
```

### Basic Windows Catlet
```ruby
config.vm.provider :eryph do |eryph|
  eryph.project = "windows-dev"
  eryph.parent = "dbosoft/winsrv2022-standard/latest" 
  eryph.enable_winrm = true
  eryph.vagrant_password = "SecureP@ss123"
  eryph.cpu = 4
  eryph.memory = 4096
end

config.vm.communicator = "winrm"
config.winrm.username = "vagrant"
config.winrm.password = "SecureP@ss123"
config.vm.guest = :windows
```

### Custom Cloud-init (Linux)
```ruby
eryph.fodder = [
  {
    name: "dev-packages",
    type: "cloud-config",
    content: {
      "packages" => ["git", "docker.io", "nodejs"],
      "runcmd" => [
        "systemctl enable docker",
        "usermod -aG docker vagrant"
      ]
    }
  }
]
```

### Custom PowerShell Setup (Windows)
```ruby
eryph.fodder = [
  {
    name: "dev-tools",
    type: "shellscript",
    content: <<~POWERSHELL
      #ps1_sysnative
      # Install Chocolatey
      Set-ExecutionPolicy Bypass -Scope Process -Force
      iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
      
      # Install development tools
      choco install -y git vscode nodejs python3
    POWERSHELL
  }
]
```

### Resource Configuration
```ruby
# High-performance configuration
eryph.cpu = 8
eryph.memory = 16384

# Custom storage
eryph.drives = [
  { name: "data-drive", size: 100 },
  { name: "backup-drive", size: 50 }
]

# Network configuration
eryph.networks = [
  { name: "app-network", adapter_name: "eth1" },
  { name: "db-network", adapter_name: "eth2" }
]
```

### Multi-machine Setup
```ruby
# Web server
config.vm.define "web" do |web|
  web.vm.provider :eryph do |eryph|
    eryph.project = "webapp"
    eryph.parent = "dbosoft/ubuntu-22.04/latest"
  end
end

# Database server
config.vm.define "db" do |db|
  db.vm.provider :eryph do |eryph|
    eryph.project = "webapp"
    eryph.parent = "dbosoft/winsrv2022-standard/latest"
    eryph.enable_winrm = true
  end
end
```

## Best Practices

### Performance Optimization
1. **Resource Allocation**
   - Start with minimal resources, scale as needed
   - Windows catlets typically need 4GB+ RAM
   - Linux catlets can run efficiently with 1-2GB RAM

2. **Storage Management**
   - Use additional drives for data to avoid root disk growth
   - Consider backup drive configuration for important data
   - Monitor disk usage in long-running catlets

3. **Network Configuration**
   - Use dedicated networks for multi-tier applications
   - Configure appropriate security groups/firewall rules
   - Consider network performance for data-intensive applications

### Security Considerations
1. **Credential Management**
   - Never hardcode passwords in Vagrantfiles
   - Use strong passwords for Windows catlets
   - Regularly rotate service credentials

2. **SSH Key Management**
   - Use `ssh_key_injection: :direct` for better security
   - Rotate SSH keys periodically
   - Use separate keys for different environments

3. **Network Security**
   - Isolate sensitive catlets on separate networks
   - Configure minimal required network access
   - Use WinRM over HTTPS for production Windows catlets

### Development Workflow
1. **Testing Strategy**
   - Test configurations locally before deployment
   - Use version control for Vagrantfiles and fodder
   - Validate cloud-init scripts before applying

2. **Environment Management**
   - Use separate projects for dev/test/prod
   - Document resource requirements
   - Implement proper cleanup procedures

3. **Troubleshooting Approach**
   - Check Eryph service logs first
   - Validate network connectivity
   - Test cloud-init scripts independently

## Troubleshooting

### Common Issues

#### Catlet Creation Failures
**Symptoms**: Catlet fails to create or times out
**Causes**:
- Insufficient host resources
- Gene not available or corrupted
- Network configuration conflicts
- Invalid fodder configuration

**Solutions**:
1. Check host resource availability
2. Verify gene name and version
3. Validate network configuration
4. Test cloud-init syntax separately

#### Network Connectivity Issues
**Symptoms**: Cannot SSH/WinRM to catlet
**Causes**:
- IP address assignment failures
- Firewall blocking connections
- Service not started (SSH/WinRM)
- Incorrect authentication

**Solutions**:
1. Check catlet IP address assignment
2. Verify firewall rules on host and catlet
3. Ensure SSH/WinRM services are running
4. Validate credentials and keys

#### Performance Problems
**Symptoms**: Slow catlet performance
**Causes**:
- Insufficient CPU/memory allocation
- Storage I/O bottlenecks
- Host resource contention
- Inefficient cloud-init scripts

**Solutions**:
1. Increase CPU/memory allocation
2. Use dedicated drives for I/O intensive workloads
3. Monitor host resource usage
4. Optimize cloud-init scripts

### Diagnostic Commands

#### Eryph Service Status
```powershell
# Check Eryph service
Get-Service eryph*

# Check Eryph logs
Get-EventLog -LogName Application -Source Eryph*
```

#### Catlet Information
```bash
# Linux catlet diagnostics
ip addr show
systemctl status ssh
journalctl -u cloud-init
```

```powershell
# Windows catlet diagnostics
Get-NetIPAddress
Get-Service WinRM
Get-EventLog -LogName System -Source Microsoft-Windows-Winlogon
```

#### Network Debugging
```bash
# Network connectivity tests
ping gateway_ip
nslookup domain.com
netstat -tlnp
```

### Log Locations
- **Host Logs**: Windows Event Viewer → Applications and Services Logs → Eryph
- **Linux Catlet Logs**: `/var/log/cloud-init*.log`
- **Windows Catlet Logs**: Event Viewer → Windows Logs → System

## Testing Guidelines

### Unit Testing
- Test configuration validation
- Test cloud-init generation
- Test SSH key management
- Mock Eryph API for offline testing

### Integration Testing
- Test with actual Eryph instance
- Validate end-to-end workflows
- Test both Linux and Windows catlets
- Verify network connectivity

### Performance Testing
- Measure catlet creation time
- Test resource utilization
- Validate concurrent operations
- Monitor memory usage

### Test Environment Setup
```bash
# Unit tests (fast, no dependencies)
rake unit

# E2E tests (requires Eryph + Vagrant)
rake e2e

# All tests
rake spec

# Install plugin for testing
rake install
```

### Test Data
Use these standard test configurations:

**Test Catlets**:
- `dbosoft/ubuntu-22.04/latest` - Ubuntu testing
- `dbosoft/winsrv2022-standard/latest` - Windows testing

**Test Projects**:
- `vagrant-test-linux` - Linux catlet testing
- `vagrant-test-windows` - Windows catlet testing
- `vagrant-test-multi` - Multi-machine testing

**Test Resources**:
- Basic: 2 CPU, 2GB RAM
- Windows: 4 CPU, 4GB RAM
- High-perf: 8 CPU, 16GB RAM

---

## Version History

- **v1.0** - Initial knowledge base creation
- **Current** - Comprehensive coverage of Eryph concepts and Vagrant integration

## Contributing

When updating this knowledge base:
1. Verify information against current Eryph documentation
2. Test configuration examples before adding
3. Update version history
4. Keep troubleshooting section current with known issues

---

*This knowledge base is maintained alongside the Vagrant Eryph plugin. For the latest Eryph documentation, visit [eryph.io/docs](https://eryph.io/docs)*