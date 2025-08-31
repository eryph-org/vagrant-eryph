# Claude Code Knowledge Base - Eryph & Vagrant Plugin

This file contains technical knowledge about Eryph and the Vagrant plugin for Claude Code to reference across chat sessions.

# general
- Ask for advice is something is happening that you don't understand.
- do not execute long auto commands without asking. 
- update this file - claude.md - if you learned something new about eryph and the way it is integated in vagrant.

## Eryph Core Architecture

### Catlets
- **Definition**: Eryph's virtual machines - like containers but full VMs
- **Lifecycle**: Create → Start → Stop → Destroy
- **States**: `:running`, `:stopped`, `:creating`, `:destroying`
- **Features**: Fast provisioning, configuration management, snapshot support

### Genes & Genesets
- **Genes**: VM image packages in format `organization/name:version`
- **Primary test genes**:
  - `dbosoft/ubuntu-22.04/latest` - Ubuntu 22.04 LTS (Linux)
  - `dbosoft-winsrv2022-standard/latest` - Windows Server 2022
  - `dbosoft/win-starter:2022` - Windows development environment
- **Genepool**: Online repository for sharing genes
- **Local storage**: Genes cached locally after first use

### Projects
- **Purpose**: Logical grouping and organization of catlets
- **Access control**: Project-based permissions and resource limits
- **Auto-creation**: Plugin can automatically create missing projects
- **Naming**: Use descriptive names like `development`, `testing`, `production`

### Fodder (Cloud-init)
- **Definition**: Eryph's term for cloud-init configuration data
- **Types**:
  - `cloud-config` - YAML-based configuration (cross-platform)
  - `shellscript` - Shell scripts for Linux
  - `powershell` - PowerShell scripts for Windows (requires filename with .ps1 extension)
- **Processing**: Multiple fodder items processed in order
- **Auto-generation**: Plugin generates user setup fodder automatically

## Vagrant Plugin Architecture

### File Structure
```
lib/vagrant-eryph/
├── plugin.rb              # Plugin registration
├── provider.rb            # Main provider class
├── config.rb              # Configuration class
├── actions.rb             # Action middleware definitions
├── actions/               # Individual action implementations
├── helpers/               # Helper classes
│   ├── cloud_init.rb      # Cloud-init generation
│   ├── ssh_key.rb         # SSH key management
│   └── eryph_client.rb    # Eryph API integration
├── errors.rb              # Error classes
├── command.rb             # CLI commands
└── version.rb             # Version information
```

### Key Components

#### Provider Class (`provider.rb`)
- Implements standard Vagrant provider interface
- Manages catlet state and SSH/WinRM info
- Handles action chain execution

#### Configuration Class (`config.rb`)
- **Required settings**: `project`, `parent_gene`
- **Auto-config options**: `auto_config`, `enable_winrm`, `vagrant_password`
- **Resources**: `cpu`, `memory`, `drives`, `networks`
- **Custom setup**: `fodder` array for cloud-init

#### Actions Architecture
- Standard Vagrant middleware pattern
- **Core actions**: `ConnectEryph`, `CreateCatlet`, `StartCatlet`, `StopCatlet`, `DestroyCatlet`
- **State actions**: `IsCreated`, `IsStopped`, `ReadState`, `ReadSshInfo`
- **Setup actions**: `PrepareCloudInit`

#### Cloud-init Helper (`helpers/cloud_init.rb`)
- **OS detection**: Analyzes gene name to determine Linux vs Windows
- **User setup**: Generates vagrant user with SSH keys (Linux) or password (Windows)
- **SSH key injection**: Two modes - `:direct` (in user config) or `:variable` (via write_files)
- **Fodder merging**: Combines auto-generated with user-provided fodder

## Technical Implementation Details

### Ruby Client Integration
- **Dependency**: `eryph-compute` gem (~> 1.0) - Updated gem name
- **Runtime**: `eryph-clientruntime` gem (~> 0.1)
- **New API**: `Eryph.compute_client()` unified interface
- **Credential lookup**: Hierarchical config discovery (./.eryph → ~/.config/.eryph → system)
- **Connection**: REST API with automatic endpoint detection and zero-config authentication

### Cross-platform Support

#### Linux Catlets
- **Communication**: SSH (port 22)
- **User setup**: Creates `vagrant` user with sudo access
- **SSH keys**: Automatic generation and injection
- **Package management**: Supports apt, yum, etc. via cloud-config

#### Windows Catlets
- **Communication**: WinRM (port 5985/5986)
- **User setup**: Creates `vagrant` user in Administrators group
- **Authentication**: Password-based (configurable)
- **Features**: PowerShell execution, Windows feature installation

### Configuration Patterns

#### Basic Linux Configuration
```ruby
config.vm.provider :eryph do |eryph|
  eryph.project = "my-project"
  eryph.parent_gene = "dbosoft/ubuntu-22.04/latest"
  eryph.auto_config = true
  # Uses new eryph-compute client with zero-config authentication
end
```

#### Basic Windows Configuration
```ruby
config.vm.provider :eryph do |eryph|
  eryph.project = "my-project"
  eryph.parent_gene = "dbosoft/winsrv2022-standard/latest"
  eryph.enable_winrm = true
  eryph.vagrant_password = "SecureP@ss123"
end

config.vm.communicator = "winrm"
config.winrm.username = "vagrant"
config.winrm.password = "SecureP@ss123"
config.vm.guest = :windows
```

#### Client Authentication Configuration
```ruby
config.vm.provider :eryph do |eryph|
  eryph.project = "my-project"
  eryph.parent_gene = "dbosoft/ubuntu-22.04/latest"
  
  # Client authentication options (updated for new client)
  eryph.client_id = "my-client-id"              # Optional: specific client ID  
  eryph.configuration_name = "production"       # Default: "default"
  
  # SSL configuration (verify_ssl instead of ssl_verify)
  eryph.ssl_verify = false                      # Default: false for localhost
  eryph.ssl_ca_file = "/path/to/ca.crt"         # Optional: CA certificate
end
```

### Client Authentication Fallback Logic

The plugin implements a robust client authentication fallback:

1. **Primary attempt**: Uses `configuration_name` (default: "default") with optional `client_id`
2. **Fallback to zero**: If "default" config fails, tries "zero" configuration
3. **System client**: Final fallback to built-in system client (requires admin privileges)

#### Authentication Flow
- **Remote access**: Configure custom client with proper credentials
- **Local development**: Can use system client (admin required) or configure "zero" setup
- **User guidance**: Plugin informs when system client is used and suggests creating custom client

## Recent Updates (2025-01-31)

### Updated Ruby Client Integration
- **New gem name**: `eryph-compute` (v1.0+) replaces `eryph-compute-client`
- **Enhanced operation tracking**: Real-time progress with task/resource callbacks
- **Config validation**: Pre-creation validation with detailed error reporting
- **Better error handling**: ProblemDetailsError integration for user-friendly messages
- **Simplified resource access**: OperationResult with direct catlet/resource accessors

### Improved User Experience
- **Progress feedback**: Shows task progress and resource creation in real-time
- **Early validation**: Catches config errors before expensive operations
- **Smart output**: Adapts verbosity to operation complexity
- **Enhanced errors**: Detailed API error messages with problem type info

## Development Context

### Testing Approach
- **Unit tests**: Mock components, test logic in isolation
- **Integration tests**: Require running Eryph instance
- **Mock client**: `EryphClientMock` for offline testing
- **Test environments**: 
  - `VAGRANT_ERYPH_TEST=true` - Enable test mode
  - `VAGRANT_ERYPH_INTEGRATION=true` - Enable integration tests
  - `VAGRANT_ERYPH_MOCK_CLIENT=true` - Force mock client

### Common Development Patterns

#### Enhanced Error Handling
- **ProblemDetailsError integration**: RFC 7807 compliant error details from API
- **User-friendly messages**: Detailed problem information with friendly formatting
- **Localized error messages** in `locales/en.yml`
- **Comprehensive validation** in config class with early feedback
- **Network error recovery** and retry logic
- **Progressive disclosure**: Basic errors by default, technical details with `--verbose`

#### Enhanced Operation Monitoring
- **Real-time progress**: Task and resource creation updates
- **Smart timeouts**: Configurable with progress indicators for long operations
- **Event callbacks**: `:task_new`, `:task_update`, `:resource_new`, `:log_entry`, `:status`
- **Operation results**: Rich OperationResult objects with direct resource access
- **Validation**: Pre-creation config validation with detailed error reporting

#### Operation Progress Output Example
```
==> default: Waiting for operation 456...
==> default: Validating catlet configuration...
==> default: Configuration validated successfully
==> default:   → Downloading gene
==> default:   Still working... (15s elapsed)
==> default:   ✓ Downloading gene
==> default:   → Creating virtual disk
==> default:   • Created VirtualDisk: disk-789
==> default:   ✓ Creating virtual disk
==> default:   → Creating catlet
==> default:   • Created Catlet: catlet-abc
==> default:   ✓ Creating catlet
==> default: Operation completed successfully
```

#### Resource Management
- CPU/memory allocation validation
- Drive attachment and sizing
- Network configuration and isolation
- Project-based resource organization

### Common Issues & Solutions

#### Network Connectivity
- **Problem**: Cannot connect to catlet
- **Causes**: IP assignment failure, firewall rules, service not started
- **Debug**: Check catlet IP, verify SSH/WinRM service status

#### Authentication
- **Problem**: SSH/WinRM authentication fails
- **Causes**: Key mismatch, password incorrect, user not created
- **Debug**: Verify cloud-init logs, check user creation

#### Resource Limits
- **Problem**: Catlet creation fails
- **Causes**: Insufficient host resources, quota exceeded
- **Debug**: Check host CPU/memory availability, review project limits

#### Gene Issues
- **Problem**: Gene not found or download fails
- **Causes**: Gene name typo, network issues, gene not available
- **Debug**: Verify gene name, check genepool connectivity

## API Patterns

### Async Operations
```ruby
# Create catlet (async)
result = client.create_catlet(config)
operation_id = result[:operation_id]

# Monitor progress
operation = client.wait_for_operation(operation_id, timeout: 300)
```

### Error Handling
```ruby
begin
  catlet = client.get_catlet(id)
rescue => e
  # Handle network errors, authentication failures, etc.
  raise VagrantPlugins::Eryph::Errors::EryphError, e.message
end
```

### State Management
```ruby
# Check catlet state
catlet = client.get_catlet(id)
case catlet[:state]
when :running
  # Catlet is ready
when :stopped
  # Need to start catlet
when :creating, :starting
  # Wait for operation to complete
end
```

## Code Conventions

### Configuration Validation
- Validate required fields in `validate` method
- Provide clear error messages with field names
- Support both string and symbol keys
- Handle nil values gracefully

### Cloud-init Generation
- Detect OS from gene name patterns
- Generate platform-appropriate user setup
- Merge user fodder with auto-generated content
- Preserve user customizations

### SSH Key Management
- Generate RSA keys with proper permissions
- Support both direct injection and file-based approaches
- Handle existing key preservation
- Clean up temporary key files

This knowledge base provides the essential technical context for working with Eryph and the Vagrant plugin across chat sessions.

## SSH Key Injection and Connection Issues - RESOLVED ✅

### Root Causes Identified and Fixed:

1. **Fodder Serialization Issue**: The `serialize_fodder_content` method in `create_catlet.rb` was incorrectly adding `#cloud-config\n` headers to YAML content. 
   - **Fix**: Changed from `content.to_yaml.sub("---\n", "#cloud-config\n")` to `content.to_yaml.sub(/^---\n/, '')`
   - **Reason**: Eryph expects clean YAML content since `type: "cloud-config"` already indicates the content type

2. **IP Address Extraction**: The original implementation looked for `ip_assignments` but Eryph API uses different property names.
   - **Fix**: Updated to use `network.floating_port.ip_v4_addresses` (not `network.ip_v4_addresses` which are internal only)
   - **Priority**: Check floating IPs first as they're assigned earlier and accessible from outside

3. **SSH Readiness Logic**: Initially tried to add artificial delays before returning SSH info, which conflicted with Vagrant's built-in retry logic.
   - **Fix**: Return SSH info immediately when IP is available, let Vagrant handle connection retries
   - **Key Insight**: Follow Vagrant best practices - return `nil` when not ready, return SSH info when connectivity details are available

### Correct Implementation Pattern:

```ruby
def ssh_info
  catlet = Provider.eryph_catlet(@machine)
  
  # Return nil when SSH isn't possible yet
  return nil unless catlet
  return nil unless catlet.status&.downcase == 'running'
  return nil unless (ip_address = extract_ip_address(catlet))
  
  # Return SSH info immediately when ready - let Vagrant handle connection testing
  {
    host: ip_address,
    port: 22,
    username: 'vagrant',
    private_key_path: [private_key_path.to_s] if private_key_path.exist?
  }
end
```

### WaitForCommunicator Configuration:
- Use `WaitForCommunicator` without state restrictions (removed `[:running]` parameter)
- Set `config.vm.boot_timeout = 600` in Vagrantfile for longer bootstrap time
- Trust Vagrant's SSH communicator to handle retries and connection failures

### Cloud-init Structure for Linux:
```yaml
fodder:
- name: "vagrant-user-setup"
  type: "cloud-config"
  content:
    users:
    - name: vagrant
      sudo: ['ALL=(ALL) NOPASSWD:ALL']
      shell: /bin/bash
      groups: ['sudo']
      lock_passwd: false
      ssh_authorized_keys:
      - "ssh-rsa AAAAB3... vagrant@machine"
    package_update: true
    packages: ['openssh-server']
    ssh_pwauth: false
    disable_root: false
```

This solution ensures proper SSH key injection and reliable SSH connections to catlets.

This knowledge base provides the essential technical context for working with Eryph and the Vagrant plugin across chat sessions.

# eryph code repos:
All code for eryph can be found on github org eryph-org. A local copy is also available in project parent dir "../"
This includes other clients and the core eryph project wih the eryph-zero.

# eryph-zero
eryph-zero currently runs only on Windows (using Hyper-V). Test runners require windows and eryph. Eryph can be installed by script: https://www.eryph.io/downloads/eryph-zero Test runners may have not enough ressources run full VMs. 
Docs about eryph: https://www.eryph.io/docs
Usage samples: https://github.com/eryph-org/samples

# Running Tests and Vagrant Integration

## Environment Requirements
- Windows with Hyper-V enabled (required for eryph-zero)
- Vagrant installed and accessible from command line
- Ruby environment with proper gem dependencies

## FIXED 2025-01-24: Integration Test Environment Issues ✅

**Issues Resolved**: Integration tests previously failed due to multiple problems:
1. ✅ **Command execution** - Fixed in spec_helper.rb using Open3.capture3 with proper environment passing
2. ✅ **Vagrant environment isolation** - Added proper VAGRANT_HOME isolation following vagrant-spec patterns  
3. ✅ **Temp directory management** - Improved using standard Vagrant plugin patterns
4. ✅ **File creation verification** - Added validation to catch issues early
5. ✅ **Test structure** - Refactored to follow successful Vagrant plugin patterns
6. ✅ **File mocking interference** - **KEY FIX**: Disabled file mocking for integration tests
7. ✅ **Plugin isolation** - **CRITICAL FIX**: Copy global plugins to isolated test environments

**Root Causes Identified**: 
1. **Primary**: File mocking in `tests/support/vagrant_mock.rb` intercepted `File.write` operations
2. **Secondary**: Plugin isolation prevented access to globally installed vagrant-eryph plugin in test environments

**Technical Solutions Implemented**:

1. **File Mocking Fix**: Modified `spec/spec_helper.rb` to only enable file mocking for unit tests:
```ruby
# Only enable file mocking for unit tests, NOT integration tests
unless ENV['VAGRANT_ERYPH_INTEGRATION'] == 'true'
  ENV['VAGRANT_ERYPH_ENABLE_FILE_MOCKING'] = 'true'
end
```

2. **Plugin Isolation Fix**: Copy global plugins to isolated environments:
```ruby
# Copy global plugins to isolated environment 
global_vagrant_home = original_vagrant_home || File.join(ENV['USERPROFILE'], '.vagrant.d')
if Dir.exist?(global_vagrant_home)
  # Copy plugins.json, gems/, rgloader/, bundler/ directories
  FileUtils.cp(global_plugins_json, File.join(vagrant_home, "plugins.json"))
  FileUtils.cp_r(global_gems_dir, vagrant_home)
end
```

**Verification**: All integration test scenarios now work correctly - plugin detection, file creation, and command execution all function properly in isolated environments.

**Solution**: Always run tests from Windows Command Prompt or PowerShell:

```powershell
# From PowerShell (recommended):
.\run_integration_tests.ps1

# Or manually from Command Prompt:
set VAGRANT_ERYPH_INTEGRATION=true
set VAGRANT_ERYPH_DEBUG=true
rake integration

# For quick verification:
ruby test_integration_simple.rb
```

**Technical Improvements Made**:
- `with_isolated_vagrant_environment` helper for proper Vagrant isolation
- `execute_vagrant_command` helper with debug output and error handling
- Environment variable passing through Open3.capture3
- Proper temp directory cleanup and verification
- Following patterns from vagrant-libvirt and other successful plugins

## Running Integration Tests
Integration tests require proper environment setup:

## Vagrant Configuration Requirements
For full integration tests to run (not be skipped), you need:

1. **Eryph client configuration**: Set up either:
   - A 'zero' configuration for local testing
   - Or a 'default' configuration pointing to your Eryph instance

2. **Vagrant plugin installation**: The plugin must be properly installed in Vagrant:
   ```bash
   gem build vagrant-eryph.gemspec
   vagrant plugin install ./vagrant-eryph-*.gem
   ```

3. **Test environment**: Integration tests require actual Eryph connectivity
   - Tests will be skipped if Eryph client can't connect
   - Message: "Could not resolve 'zero' configuration: No client configuration found"

## Troubleshooting Test Failures
- **Vagrant not found**: Use Command Prompt or PowerShell instead of Git Bash
- **Integration tests skipped**: Configure Eryph client or ensure eryph-zero is running
- **Generated compute client warning**: Run `generate.ps1` to regenerate API client if needed

# Test-Driven Development (TDD) Approach - 2025-01-31

## Mandatory TDD Process - EVERY BUG FIX MUST HAVE A FAILING TEST FIRST

### The TDD Cycle

1. **Write a failing test** that demonstrates the bug
2. **Run the test** and confirm it fails for the right reason
3. **Write minimal code** to make the test pass
4. **Run all tests** to ensure no regression
5. **Refactor** if needed while keeping tests green

### Critical Bugs That Should Have Had Tests

#### UNSET_VALUE Setter Bug (Fixed 2025-01-31)
**Bug**: Ruby-style setters crashed when called before `finalize!` because `@catlet ||= {}` failed with `UNSET_VALUE` (Symbol)

**Test that should have existed:**
```ruby
it 'handles setter methods with UNSET_VALUE' do
  config = described_class.new
  # Before finalize!, @catlet is UNSET_VALUE
  expect(config.instance_variable_get(:@catlet)).to eq(UNSET_VALUE)
  
  # This would crash without the fix
  config.parent = "dbosoft/ubuntu-22.04/latest"
  config.cpus = 2
  
  # Should work after fix
  expect(config.parent).to eq("dbosoft/ubuntu-22.04/latest")
  expect(config.cpus).to eq(2)
end
```

#### Configuration Name Default Bug (Fixed 2025-01-31)
**Bug**: `configuration_name` defaulted to `'default'` instead of `nil`, causing Ruby client issues

**Test that should have existed:**
```ruby
it 'defaults configuration_name to nil not default string' do
  config = described_class.new
  config.finalize!
  
  # Should be nil for automatic credential discovery
  expect(config.configuration_name).to be_nil
end
```

### TDD Implementation Rules

#### For ALL Bug Fixes:
1. **Before touching production code**, write a test that reproduces the bug
2. **Run the test** - it must FAIL for the right reason
3. **Fix the bug** with minimal code changes
4. **Run the test again** - it must now PASS
5. **Run full test suite** - no regressions allowed

### New Test Strategy (2025-01-31)

#### Unit Tests with Vagrant Simulation
- Use realistic Vagrant mock with CORRECT constants (`UNSET_VALUE = :__UNSET__VALUE__`)
- Test real behavior, not mocked responses  
- Focus on configuration bugs, state management, error handling
- NO environment dependencies

#### E2E Tests with Real Environment
- Execute actual `vagrant` commands
- Test complete deployment lifecycle
- **FAIL when dependencies missing** (no environment checks!)
- Assume Vagrant + Eryph + plugin are ready

#### NO Integration Tests
Integration tests without real components test nothing meaningful - they verify mocks work with mocks.

### Test Commands
```bash
rake unit    # Fast unit tests with simulation
rake e2e     # Full E2E tests (assumes environment ready)  
rake install # Build and install plugin for E2E testing
```

This TDD approach ensures every bug gets caught by automated tests, preventing regression and building confidence in the codebase.

