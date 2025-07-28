# Vagrant Eryph Plugin Test Suite

This directory contains a comprehensive test suite for the Vagrant Eryph plugin, providing validation for all components and functionality.

## Test Structure

```
tests/
├── test_runner.rb              # Main test harness
├── support/
│   └── test_helper.rb          # Test utilities and assertions
├── mocks/
│   └── eryph_client_mock.rb    # Mock Eryph client for offline testing
├── unit/                       # Unit tests for individual components
│   ├── config_test.rb          # Configuration class tests
│   ├── cloud_init_test.rb      # Cloud-init helper tests
│   └── ssh_key_test.rb         # SSH key management tests
├── integration/                # Integration tests with Eryph
│   ├── linux_catlet_test.rb    # Linux catlet integration tests
│   └── windows_catlet_test.rb  # Windows catlet integration tests
├── e2e/                        # End-to-end tests
│   └── full_lifecycle_test.rb  # Complete catlet lifecycle tests
├── fixtures/                   # Test data and configurations
│   └── test_vagrantfiles/      # Test Vagrantfile configurations
│       ├── basic_linux.rb      # Basic Linux catlet
│       ├── basic_windows.rb    # Basic Windows catlet
│       ├── custom_fodder_linux.rb    # Linux with custom cloud-init
│       ├── custom_fodder_windows.rb  # Windows with custom setup
│       ├── multi_machine.rb    # Multi-machine configuration
│       └── resource_intensive.rb     # High-resource configuration
├── structure_test.rb           # Plugin structure validation
├── installation_test.rb        # Plugin installation tests
└── tmp/                        # Temporary test files
```

## Running Tests

### Full Test Suite
```bash
# Run all tests
ruby tests/test_runner.rb
```

### Individual Test Categories
```bash
# Structure validation only
ruby tests/structure_test.rb

# Unit tests only
ruby tests/unit/config_test.rb
ruby tests/unit/cloud_init_test.rb
ruby tests/unit/ssh_key_test.rb

# Installation tests
ruby tests/installation_test.rb

# Mock integration tests
VAGRANT_ERYPH_MOCK_CLIENT=true ruby tests/e2e/full_lifecycle_test.rb
```

### Integration Tests (Requires Eryph)
```bash
# Enable integration testing
export VAGRANT_ERYPH_INTEGRATION=true

# Run Linux catlet tests
ruby tests/integration/linux_catlet_test.rb

# Run Windows catlet tests  
ruby tests/integration/windows_catlet_test.rb

# Run full end-to-end tests
ruby tests/e2e/full_lifecycle_test.rb
```

## Test Modes

### 1. Offline Mode (Default)
- Uses mock Eryph client
- Tests plugin logic without requiring Eryph installation
- Fast execution for development and CI/CD

### 2. Integration Mode
Set `VAGRANT_ERYPH_INTEGRATION=true` to:
- Test against actual Eryph instance
- Validate real catlet creation and management
- Test SSH/WinRM connectivity

### 3. Debug Mode
Set `VAGRANT_ERYPH_DEBUG=true` to:
- Enable verbose logging
- Show detailed test output
- Preserve temporary files for inspection

## Test Categories

### Structure Tests
- Validate all required files exist
- Check plugin registration
- Verify configuration options
- Test localization files

### Unit Tests
- **Configuration**: Test all config options and validation
- **Cloud-init**: Test fodder generation for Linux and Windows
- **SSH Keys**: Test key generation and management
- **Helpers**: Test utility functions

### Installation Tests
- Test gem building process
- Validate Vagrant plugin installation
- Verify plugin is properly registered
- Test plugin uninstallation

### Integration Tests
- **Linux Catlets**: Ubuntu catlet lifecycle testing
- **Windows Catlets**: Windows Server catlet testing
- Test SSH and WinRM connectivity
- Validate cloud-init execution
- Test custom configurations

### End-to-End Tests
- Complete catlet lifecycle (create → start → stop → destroy)
- Multi-machine configurations
- Resource management
- Error handling scenarios
- Concurrent operations

## Test Data

### Standard Test Genes
- `dbosoft/ubuntu-22.04/latest` - Linux testing
- `dbosoft-winsrv2022-standard/latest` - Windows testing

### Test Projects
- `test-basic-linux` - Basic Linux configurations
- `test-basic-windows` - Basic Windows configurations
- `test-custom-fodder` - Custom cloud-init testing
- `test-multi-machine` - Multi-catlet scenarios
- `test-resource-intensive` - High-resource configurations

### Test Configurations
Available in `tests/fixtures/test_vagrantfiles/`:
- **basic_linux.rb**: Minimal Linux catlet
- **basic_windows.rb**: Minimal Windows catlet
- **custom_fodder_linux.rb**: Linux with development tools
- **custom_fodder_windows.rb**: Windows with development environment
- **multi_machine.rb**: Multi-tier application setup
- **resource_intensive.rb**: High-performance configuration

## Environment Variables

### Test Control
- `VAGRANT_ERYPH_TEST=true` - Enable test mode
- `VAGRANT_ERYPH_DEBUG=true` - Enable debug output
- `VAGRANT_ERYPH_INTEGRATION=true` - Enable integration tests
- `VAGRANT_ERYPH_MOCK_CLIENT=true` - Force mock client usage

### Specialized Tests
- `VAGRANT_ERYPH_NETWORK_TEST=true` - Enable network configuration tests
- `VAGRANT_ERYPH_DRIVE_TEST=true` - Enable drive attachment tests

## Mock Client

The `EryphClientMock` class provides:
- Simulated Eryph API responses
- Configurable operation delays
- Error simulation capabilities
- State tracking for testing
- Concurrent operation support

### Mock Client Features
```ruby
# Create mock client
client = EryphClientMock.new

# Simulate operations
client.create_catlet(config)
client.simulate_catlet_running(catlet_id)
client.simulate_error(:network_error)

# Test concurrent operations
client.set_operation_delay(0.1)
```

## Test Reports

Test results are saved to:
- `tests/tmp/test_report.json` - Detailed test results
- Console output with colored status indicators
- CI/CD pipeline artifacts

### Report Format
```json
{
  "summary": {
    "total": 45,
    "passed": 43,
    "failed": 2,
    "duration": 12.34,
    "timestamp": "2024-01-15T10:30:00Z"
  },
  "results": [...],
  "failures": [...]
}
```

## Continuous Integration

The test suite integrates with GitHub Actions:
- **Test Matrix**: Multiple Ruby versions and platforms
- **Parallel Execution**: Different test categories run concurrently
- **Artifact Upload**: Test results and built gems
- **Security Scanning**: Automated vulnerability checks
- **Performance Testing**: Benchmark critical operations

### CI Test Stages
1. **Structure & Unit Tests**: Fast validation of plugin structure
2. **Integration Tests**: Vagrant plugin installation and basic functionality
3. **Security Scan**: Dependency and code security analysis
4. **Documentation Check**: Verify documentation completeness
5. **Performance Tests**: Benchmark test execution and plugin performance

## Contributing to Tests

### Adding New Tests
1. Choose appropriate test category (unit/integration/e2e)
2. Follow existing test patterns and naming conventions
3. Include both positive and negative test cases
4. Add proper documentation and comments
5. Update this README if adding new test categories

### Test Guidelines
- Use descriptive test method names
- Include assertion messages for clarity
- Test edge cases and error conditions
- Clean up resources after tests
- Use appropriate test isolation

### Mock Updates
When updating the mock client:
1. Maintain compatibility with existing tests
2. Add new features incrementally
3. Update documentation for new mock capabilities
4. Test mock behavior against real Eryph API when possible

## Troubleshooting Tests

### Common Issues
- **Permission Errors**: Run with appropriate privileges for Vagrant operations
- **Network Issues**: Check Eryph service availability for integration tests
- **Timeout Errors**: Increase timeout values for slow systems
- **Mock Inconsistencies**: Verify mock client matches real API behavior

### Debug Techniques
```bash
# Enable maximum verbosity
export VAGRANT_ERYPH_DEBUG=true
export VAGRANT_LOG=debug

# Run specific failing test
ruby tests/unit/config_test.rb

# Preserve test artifacts
export VAGRANT_ERYPH_PRESERVE_TEMP=true
```

---

For more information about the Vagrant Eryph plugin, see the main [README.md](../README.md) and [ERYPH_KNOWLEDGE.md](../ERYPH_KNOWLEDGE.md).