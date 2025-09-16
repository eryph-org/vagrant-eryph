# Vagrant Eryph Provider

A Vagrant provider plugin for [Eryph](https://www.eryph.io/) that allows you to manage catlets using Eryph's compute API.

## Features

- Full catlet lifecycle management (create, start, stop, destroy)
- Automatic Vagrant user setup via cloud-init
- Cross-platform support (Linux and Windows catlets)
- SSH and WinRM communication support
- Local-scoped credential discovery
- Configurable cloud-init fodder merging

## Installation

```bash
gem install vagrant-eryph
```

## Usage

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :eryph do |eryph|
    eryph.project = "my-project"
    eryph.parent = "dbosoft/ubuntu-22.04/latest"
    eryph.auto_config = true  # Enable automatic Vagrant user setup
  end
end
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

```bash
bundle install
bundle exec vagrant --help
```

## License

MIT