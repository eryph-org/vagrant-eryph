# Testing the Vagrant Eryph Plugin

This document describes how to test the Vagrant Eryph plugin with your local Eryph installation.

## Prerequisites

- **Windows with Hyper-V** (required for Eryph zero)
- **Eryph installed and running** (download from https://www.eryph.io/downloads/eryph-zero)
- **Vagrant installed** (2.2.0 or later)
- **Ruby** (2.7.0 or later)

## Quick Start

### Windows (Recommended)
```cmd
# Run complete test suite (setup + unit + integration)
scripts\test.bat all

# Or run individual commands
scripts\test.bat setup       # Build and install plugin
scripts\test.bat unit        # Unit tests only
scripts\test.bat integration # Integration tests with Eryph
scripts\test.bat clean       # Clean up
```

### Cross-platform (Limited)
```bash
# Run complete test suite
./scripts/test.sh all

# Or run individual commands  
./scripts/test.sh setup       # Build and install plugin
./scripts/test.sh unit        # Unit tests only
./scripts/test.sh integration # Integration tests (requires Eryph)
./scripts/test.sh clean       # Clean up
```

## Test Categories

### 1. Unit Tests (No Eryph Required)
- **Structure Tests**: Plugin file validation
- **Configuration Tests**: Config class validation
- **Helper Tests**: SSH key and cloud-init helpers
- **Mock Tests**: Using simulated Eryph client

```cmd
scripts\test.bat unit
```

### 2. Integration Tests (Requires Eryph)
- **Installation Tests**: Real Vagrant plugin installation
- **Linux Catlet Tests**: Ubuntu catlet lifecycle
- **Windows Catlet Tests**: Windows Server catlet lifecycle  
- **End-to-End Tests**: Complete workflows

```cmd
scripts\test.bat integration
```

## Manual Testing

### Install Plugin Manually
```cmd
# Build and install
gem build vagrant-eryph.gemspec
vagrant plugin install vagrant-eryph-*.gem

# Verify installation
vagrant plugin list | findstr vagrant-eryph
```

### Test Basic Functionality
```cmd
# Create test directory
mkdir test-catlet && cd test-catlet

# Create Vagrantfile
echo Vagrant.configure("2") do ^|config^| > Vagrantfile
echo   config.vm.provider :eryph do ^|eryph^| >> Vagrantfile
echo     eryph.project = "test-project" >> Vagrantfile  
echo     eryph.parent_gene = "dbosoft/ubuntu-22.04/latest" >> Vagrantfile
echo   end >> Vagrantfile
echo end >> Vagrantfile

# Test commands
vagrant validate
vagrant status
vagrant up --provider=eryph    # Creates catlet
vagrant ssh                    # Connect to catlet
vagrant halt                   # Stop catlet
vagrant destroy -f             # Remove catlet
```

### Test Windows Catlet
```ruby
# Create Vagrantfile for Windows
Vagrant.configure("2") do |config|
  config.vm.provider :eryph do |eryph|
    eryph.project = "windows-test"
    eryph.parent_gene = "dbosoft-winsrv2022-standard/latest"
    eryph.enable_winrm = true
    eryph.vagrant_password = "TestP@ss123"
  end
  
  config.vm.communicator = "winrm"
  config.winrm.username = "vagrant"
  config.winrm.password = "TestP@ss123"
  config.vm.guest = :windows
end
```

## Environment Variables

- `VAGRANT_ERYPH_INTEGRATION=true` - Enable integration tests
- `VAGRANT_ERYPH_DEBUG=true` - Enable debug output
- `VAGRANT_LOG=debug` - Verbose Vagrant logging
- `VAGRANT_ERYPH_MOCK_CLIENT=true` - Force mock client for offline testing

## Test Genes Available

### Linux
- `dbosoft/ubuntu-22.04/latest` - Ubuntu 22.04 LTS
- `dbosoft/ubuntu:22.04` - Alternative Ubuntu format

### Windows  
- `dbosoft-winsrv2022-standard/latest` - Windows Server 2022
- `dbosoft/win-starter:2022` - Windows development environment

## Troubleshooting

### Plugin Installation Issues
```cmd
# Clean reinstall
scripts\test.bat clean
scripts\test.bat setup

# Manual cleanup
vagrant plugin uninstall vagrant-eryph
del vagrant-eryph-*.gem
```

### Eryph Connection Issues
```cmd
# Check Eryph status
eryph --version
eryph config list

# Check service
Get-Service eryph*
```

### Integration Test Failures
1. **Ensure Eryph is running**: Check Windows services
2. **Check Hyper-V**: Ensure Hyper-V is enabled and working
3. **Network connectivity**: Verify eryph API is accessible
4. **Permissions**: Run as administrator if needed
5. **Resource availability**: Ensure sufficient CPU/memory

### Common Issues
- **"Catlet not found"**: May indicate network or API issues
- **Authentication failures**: Check eryph credential configuration
- **Timeout errors**: Catlet creation can take several minutes
- **Hyper-V conflicts**: Ensure no other VM software is conflicting

## Test Reports

Test results are saved to:
- `tests/tmp/test_report.json` - Unit test results
- `tests/tmp/integration_test_report.json` - Integration test results

## Contributing

When adding new tests:
1. Follow existing test patterns
2. Use appropriate test category (unit vs integration)
3. Include both positive and negative test cases
4. Update this documentation for new test scenarios

## Performance Notes

- **Unit tests**: Fast (~30 seconds)
- **Integration tests**: Slow (5-15 minutes depending on catlet creation)
- **Linux catlets**: Typically faster to create than Windows
- **Windows catlets**: Require more memory and take longer to boot

For faster development cycles, use unit tests during development and integration tests for final validation.