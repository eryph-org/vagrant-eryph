# Eryph Vagrant Plugin Examples

This directory contains working examples of Vagrantfiles using the Eryph provider. These examples demonstrate different configuration patterns and use cases.

## Configuration Format Evolution

The Eryph Vagrant plugin supports both legacy and modern configuration formats:

### Modern Format (Recommended)
```ruby
eryph.catlet = {
  parent: "dbosoft/ubuntu-22.04/latest",
  cpu: { count: 2 },
  memory: { startup: 2048 }
}
```

### Legacy Format (Still Supported)
```ruby
eryph.parent_gene = "dbosoft/ubuntu-22.04/latest"
eryph.cpu = 2
eryph.memory = 2048
```

## Example Files

### `Vagrantfile` - Basic Ubuntu Linux
- **Purpose**: Simple Ubuntu development environment
- **Features**: Auto-configuration, SSH setup, basic provisioning
- **Best for**: Development, learning, quick testing

### `Vagrantfile.windows` - Windows Server
- **Purpose**: Windows Server 2022 catlet with WinRM
- **Features**: WinRM communication, PowerShell provisioning, Chocolatey
- **Best for**: Windows development, testing Windows applications

### `Vagrantfile.legacy` - Backward Compatibility
- **Purpose**: Shows older configuration format
- **Features**: parent_gene format, legacy resource specification
- **Best for**: Migrating existing configurations

### `Vagrantfile.multi-machine` - Multi-Machine Setup
- **Purpose**: Web server and database in same project
- **Features**: Multiple catlets, shared project, different configurations
- **Best for**: Full-stack development, microservices testing

### `Vagrantfile.advanced` - Advanced Configuration
- **Purpose**: Production-like setup with custom resources
- **Features**: Custom drives/networks, security hardening, complex provisioning
- **Best for**: Production testing, complex deployments

## Common Configuration Options

### Required Settings
```ruby
eryph.project = "my-project"              # Project name
# Choose one:
eryph.catlet = { parent: "gene-name" }     # Modern format
# OR
eryph.parent_gene = "gene-name"            # Legacy format
```

### Auto-Configuration (Recommended)
```ruby
eryph.auto_config = true                   # Creates vagrant user automatically
eryph.auto_create_project = true           # Creates project if missing
```

### Client Configuration
```ruby
eryph.configuration_name = "default"       # Eryph client config name
eryph.client_id = "custom-client"          # Optional: specific client ID
```

### Cloud-Init (Fodder)
```ruby
eryph.fodder = [
  {
    name: "setup-script",
    type: "cloud-config",                   # or "shellscript", "powershell"
    content: {
      "packages" => ["git", "curl"],
      "runcmd" => ["echo 'Setup complete'"]
    }
  }
]
```

## Available Parent Genes

### Linux
- `dbosoft/ubuntu-22.04/latest` - Ubuntu 22.04 LTS (recommended)
- `dbosoft/ubuntu/latest` - Latest Ubuntu

### Windows  
- `dbosoft/winsrv2022-standard/latest` - Windows Server 2022
- `dbosoft/win-starter:2022` - Windows development environment

## Usage Instructions

1. **Choose an example** that matches your use case
2. **Copy the Vagrantfile** to your project directory
3. **Customize the configuration** (project name, resources, etc.)
4. **Ensure Eryph client is configured** (see CLAUDE.md for setup)
5. **Run Vagrant commands**:
   ```bash
   vagrant up --provider=eryph
   vagrant ssh  # Linux catlets
   vagrant rdp  # Windows catlets
   vagrant halt
   vagrant destroy
   ```

## Prerequisites

- Vagrant installed
- Eryph client configured (zero, default, or custom configuration)
- Windows with Hyper-V (for eryph-zero) or access to remote Eryph instance
- Eryph Vagrant plugin installed: `vagrant plugin install vagrant-eryph`

## Troubleshooting

### Common Issues
1. **"No parent specified"** - Set `eryph.catlet.parent` or `eryph.parent_gene`
2. **"Project not found"** - Enable `eryph.auto_create_project = true`
3. **Connection failures** - Check Eryph client configuration
4. **SSH/WinRM issues** - Verify `eryph.auto_config = true` is set

### Getting Help
- Check the main CLAUDE.md file for detailed technical information
- Review the configuration class in `lib/vagrant-eryph/config.rb`
- Enable debug mode: `VAGRANT_LOG=debug vagrant up`

## Contributing

When adding new examples:
1. Use the modern `catlet = {}` configuration format
2. Include comprehensive comments
3. Test with actual Eryph instance
4. Update this README with description