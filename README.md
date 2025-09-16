# Vagrant Eryph Provider

A Vagrant provider plugin for [Eryph](https://www.eryph.io/) that allows you to manage catlets using Eryph's compute API.

## Features

- Full catlet lifecycle management (create, start, stop, destroy)
- Automatic Vagrant user setup via cloud-init
- Cross-platform support (Linux and Windows catlets)
- SSH and WinRM communication support
- Local-scoped credential discovery
- Configurable cloud-init fodder merging

## Requirements

- **Vagrant** 2.0 or later
- **Ruby** >= 3.1.0
- **Eryph** - either:
  - [Eryph-zero](https://www.eryph.io/downloads/eryph-zero) >= 0.4.1 installed locally or remotely
  - For client management: [PowerShell module](https://www.powershellgallery.com/packages/Eryph.ComputeClient) (works on Windows/Linux/macOS)

See the [Eryph documentation](https://www.eryph.io/docs) for installation and setup instructions.

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

### Resources
- `cpus` - Number of CPUs
- `memory` - Memory in MB
- `drives` - Custom drives configuration
- `networks` - Custom networks configuration

### Cloud-init
- `fodder` - Custom cloud-init configuration (merged with auto-generated config)

## Project Management

The plugin includes commands to manage Eryph projects:

```bash
# List projects
vagrant eryph project list

# Create project
vagrant eryph project create my-project --description "My development project"

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

# Run E2E tests (requires Eryph)
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