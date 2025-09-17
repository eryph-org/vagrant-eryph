# vagrant eryph Provider

This is a vagrant provider plugin for [eryph](https://www.eryph.io) that allows you to manage virtual machines as catlets, which are VMs built from specification files (catlets are pure declarative VM configurations).  

Eryph brings cloud-native features to local/on-premises development environments, such as storage management, virtual networks, and secure remote access. It is built on top of Hyper-V, but hides most of it. 

## Why choose the eryph provider?

- **Standard VMs work instantly** - Use any gene/template from eryph's genepool (https://genepool.eryph.io), Vagrant configuration is automatically injected via cloud-init.
- **Project isolation with SDN** - Full software-defined networking with isolated projects, virtual networks, and proper routing
- **API-based remote access** - Develop from anywhere: WSL, Linux, macOS clients can all connect to Windows eryph hosts
- **Non-admin access** - Unlike Hyper-V provider, you don't need local admin rights

**What Cloud-Native Features You Get:**
- **Storage management** - Automatic creation/removal of disks and VM files
- **Software-Defined Networking** - Create complex network topologies per project, not just basic VM networking
- **Multi-platform development** - Windows eryph hosts serve WSL/Linux/macOS developers via REST API
- **Team collaboration** - Share infrastructure with project-based access control and resource limits
- **Hyper-V compatibility** - Familiar vagrant settings (cpus, memory, etc.) just work
- **Template inheritance** - Use eryph genes system to merge configuration instead of building it into each vagrantfile.

## Requirements

- **Vagrant** 2.0 or later
- **Ruby** >= 3.1.0
- **eryph** - either:
  - [eryph-zero](https://www.eryph.io/downloads/eryph-zero) >= 0.4.1 installed locally or remotely
  - For client management: [PowerShell module](https://www.powershellgallery.com/packages/Eryph.ClientRuntime.Configuration) (works on Windows/Linux/macOS)

See the [eryph documentation](https://www.eryph.io/docs) for installation and setup instructions.

## Installation

Install the plugin using Vagrant's plugin system:

```bash
vagrant plugin install vagrant-eryph
```

Or install from a local gem file:

```bash
vagrant plugin install ./vagrant-eryph-*.gem
```

## Usage

### Basic Linux Example

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :eryph do |eryph|
    eryph.parent = "dbosoft/ubuntu-22.04"
  end
end
```

Run with:
```bash
vagrant up --provider=eryph
```

### Windows Example

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :eryph do |eryph|
    eryph.parent = "dbosoft/winsrv2022-standard"
    eryph.enable_winrm = true
    eryph.vagrant_password = "SecureP@ss123"
    eryph.cpus = 4
    eryph.memory = 4096
  end

  # Configure Windows communication
  # eryph requires https by default
  config.vm.communicator = "winrm"
  config.winrm.username = "vagrant"
  config.winrm.password = "SecureP@ss123"
  config.winrm.port = 5986
  config.winrm.transport = :ssl
  config.winrm.ssl_peer_verification = false
  config.winrm.basic_auth_only = true
  config.vm.guest = :windows
end
```

Run with:
```bash
vagrant up --provider=eryph
```

### Advanced Configuration Example

Combining individual helpers with direct configuration and complex setups. The individual property helpers are intentionally compatible with most used Hyper-V provider settings for easy migration:

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :eryph do |eryph|
    eryph.project = "development"

    # Option 1: Use individual property helpers (mapped to catlet hash)
    eryph.parent = "dbosoft/ubuntu-22.04"
    eryph.cpus = 4
    eryph.memory = 4096
    eryph.maxmemory = 8192  # Enables dynamic memory
    eryph.enable_virtualization_extensions = true

    # Option 2: Or use direct catlet hash for complex scenarios
    # eryph.catlet = {
    #   parent: "dbosoft/ubuntu-22.04",
    #   cpu: { count: 4 },
    #   memory: { startup: 4096, maximum: 8192 },
    #   capabilities: [
    #     { name: "nested_virtualization" },
    #     { name: "dynamic_memory" }
    #   ]
    # }

    # Add additional drives using helper method
    eryph.add_drive("data", size: 100, type: :vhd)
    eryph.add_drive("logs", size: 50, type: :vhd)

    # Add gene-based fodder for common setup tasks
    eryph.add_fodder_gene("dbosoft", "development-tools",
                          fodder_name: "dev-setup")

    # Add custom cloud-config
    eryph.cloud_config("app-config") do |config|
      config["packages"] = ["nginx", "nodejs", "git"]
      config["runcmd"] = ["systemctl enable nginx"]
    end

    # Set variables for use in fodder
    eryph.set_variable("environment", "development")
    eryph.set_variable("app_version", "latest")
  end
end
```

### Setting Default Provider

To avoid specifying `--provider=eryph` every time:

```bash
export VAGRANT_DEFAULT_PROVIDER=eryph
# or on Windows:
set VAGRANT_DEFAULT_PROVIDER=eryph
```

## Configuration

### Basic Settings
- `project` - Eryph project name
- `parent` - Parent gene for the catlet
- `auto_create_project` - Auto-create project if it doesn't exist (default: true)

### Auto-configuration
- `auto_config` - Enable/disable automatic Vagrant user setup (default: true)
- `enable_winrm` - Enable WinRM for Windows catlets (default: true)
- `vagrant_password` - Password for Windows vagrant user (default: "vagrant")
- `ssh_key_injection` - SSH key injection method (:direct or :variable)

### Catlet Configuration

**Individual property helpers** (automatically mapped to catlet hash):
- `cpus` - Number of CPUs (maps to `catlet[:cpu][:count]`)
- `memory` - Memory in MB (maps to `catlet[:memory][:startup]`)
- `maxmemory` - Maximum memory in MB (enables dynamic memory capability)
- `parent` - Parent gene (maps to `catlet[:parent]`)
- `vmname` - VM name (maps to `catlet[:name]`)
- `hostname` - Network hostname (maps to `catlet[:hostname]`)
- `enable_virtualization_extensions` - Enable nested virtualization
- `enable_secure_boot` - Enable secure boot capability

**Direct configuration:**
- `catlet` - Direct catlet configuration hash (alternative to individual settings)

**Helper methods for complex configurations:**
```ruby
# Add drives with type mapping
add_drive("data", size: 100, type: :vhd)
add_drive("shared", type: :shared_vhd, source: "my-shared-disk")

# Add gene-based fodder
add_fodder_gene("dbosoft", "base-setup", fodder_name: "setup", variables: [...])

# Add cloud-config fodder
cloud_config("my-setup") do |config|
  config["packages"] = ["nginx", "git"]
end

# Add shell script fodder
shell_script("post-install", "#!/bin/bash\necho 'Done'")

# Manage capabilities
enable_capability("nested_virtualization")
disable_capability("secure_boot")

# Set variables for fodder
set_variable("app_name", "myapp")
```

### Automatic Cloud-Init Integration

The plugin automatically generates cloud-init configuration:
- **Linux**: Creates vagrant user with sudo access, SSH keys, and password authentication
- **Windows**: Creates vagrant user in Administrators group with password and SSH keys
- **Merging**: Auto-generated fodder is intelligently merged with user-provided fodder
- **Compatibility**: Converts Vagrant cloud-init configs to eryph fodder format

**Fodder vs Cloud-Init relationship:**
- eryph uses "fodder" (supports cloud-init, shell scripts, PowerShell, etc.)
- Plugin auto-generates vagrant user setup as cloud-config fodder
- User fodder configurations are merged with auto-generated ones
- Duplicates are automatically handled using source/name keys

For detailed catlet configuration options and specification format, see the [eryph Specification Files documentation](https://www.eryph.io/docs/refs/specification-files).

### Client Configuration
- `configuration_name` - eryph client configuration name (default: automatic discovery)
- `client_id` - Specific client ID for authentication
- `ssl_verify` - Enable/disable SSL certificate verification (default: false for localhost)
- `ssl_ca_file` - Path to custom CA certificate file

## Client Management

The plugin uses eryph's client configuration system for authentication and connection management. Client configurations are managed through PowerShell commands and store connection details, credentials, and endpoints.

### Configuration Discovery

Eryph uses two main configuration types:
1. **"zero" configuration** - For local eryph-zero instances (automatic endpoint discovery)
2. **"default" configuration** - For remote eryph hosts (manually configured)

The plugin automatically discovers configurations in this order:
1. **Named configuration** (if `configuration_name` is specified)
2. **"default" configuration** (for remote hosts)
3. **"zero" configuration** (for local eryph-zero)
4. **System client** (requires admin privileges)

### Managing Client Configurations

Use PowerShell commands to manage client configurations (works on Windows, Linux, and macOS):

```powershell
# Install the configuration module
Install-Module Eryph.ClientRuntime.Configuration

# List available configurations
Get-EryphClientConfiguration

# Create a client with compute permissions and add to default configuration
New-EryphClient my-client `
     -AllowedScopes compute:write `
     -AddToConfiguration -AsDefault

# For remote hosts, create default configuration manually
New-EryphClientConfiguration -Name "default" -Endpoint "https://eryph.company.com"

# Remove a configuration
Remove-EryphClientConfiguration -Name "old-config"
```

### Vagrantfile Examples

```ruby
# Use automatic discovery (recommended for local development)
config.vm.provider :eryph do |eryph|
  eryph.parent = "dbosoft/ubuntu-22.04"
  # No client config needed - uses automatic discovery
end

# Use specific named configuration
config.vm.provider :eryph do |eryph|
  eryph.parent = "dbosoft/ubuntu-22.04"
  eryph.configuration_name = "default"
end

# Use specific client ID with custom SSL settings
config.vm.provider :eryph do |eryph|
  eryph.parent = "dbosoft/ubuntu-22.04"
  eryph.configuration_name = "default"
  eryph.client_id = "my-automation-client"
  eryph.ssl_verify = true
  eryph.ssl_ca_file = "/path/to/ca.crt"
end
```

### Troubleshooting Authentication

If you encounter authentication issues:

1. **Check available configurations**: `Get-EryphClientConfiguration`
2. **Check credentials**: `Get-EryphClientCredential -Name "your-config"`
3. **Verify permissions**: Ensure the client has appropriate compute scopes
4. **Check logs**: Use `vagrant up --debug` for detailed connection information

For detailed client configuration and authentication setup, see the [eryph PowerShell documentation](https://www.eryph.io/docs/using-powershell#client-configuration).

## Project Management

The plugin includes commands to manage eryph projects:

```bash
# List projects
vagrant eryph project list

# Create project
vagrant eryph project create my-project

# Manage project networks
vagrant eryph network get my-project
vagrant eryph network set my-project --file networks.yml
```


## Development

### Setup

```bash
bundle install
```

### Building and Testing

```bash
# Build gem
rake build

# Install locally for testing
rake install

# Reinstall after changes
rake reinstall

# Run unit tests (fast)
rake unit

# Run E2E tests (requires eryph)
rake e2e

# Run all tests
rake spec

# Get detailed test information
rake test_info
```

### Manual Installation

```bash
# Build gem manually
gem build vagrant-eryph.gemspec

# Install locally
vagrant plugin install ./vagrant-eryph-*.gem

# Uninstall
vagrant plugin uninstall vagrant-eryph
```

## License

MIT
