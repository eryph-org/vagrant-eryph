# Test Strategy for Vagrant Eryph Plugin

## Core Testing Philosophy

### NO Integration Tests
Integration tests without real components are just "elaborate unit tests" that test our code talking to itself. They provide false confidence because they verify that mocks work with mocks, not that our code works with real systems.

### Two-Tier Testing Strategy

1. **Unit Tests** (70% of effort)
   - Test individual components with realistic simulation
   - Fast feedback loop (milliseconds)
   - No external dependencies

2. **E2E Tests** (30% of effort)
   - Test complete user workflows with real systems
   - Full confidence in integration
   - Slower but provides real validation

## Unit Tests with Vagrant Simulation

### What We Test
- Configuration lifecycle with REAL Vagrant constants (`UNSET_VALUE = :__UNSET__VALUE__`)
- Ruby-style setter methods and state management
- Provider state mapping and SSH info extraction
- Error handling and edge cases
- Complex configuration transformations

### What We DON'T Mock
- Our own classes and methods
- Simple data structures and transformations
- Basic Ruby functionality
- Vagrant constants and interfaces

### What We DO Mock
- Network calls to Eryph API
- File system operations (when testing logic, not I/O)
- External service responses
- Time/randomness for deterministic tests

### Example: Testing the UNSET_VALUE Bug
```ruby
it 'handles the real Vagrant UNSET_VALUE correctly' do
  config = described_class.new
  
  # Before finalize!, should be UNSET_VALUE
  expect(config.instance_variable_get(:@catlet)).to eq(UNSET_VALUE)
  
  # The bug: this would fail because @catlet ||= {} doesn't work 
  # when @catlet is :__UNSET__VALUE__
  config.parent = "dbosoft/ubuntu-22.04/latest"
  
  # Should work because our setters use ensure_catlet_hash!
  expect(config.parent).to eq("dbosoft/ubuntu-22.04/latest")
end
```

## E2E Tests - Real Environment Assumptions

### Core Principle: NO Environment Checking

E2E tests assume the environment is correctly set up:
- ✅ Run `vagrant up` - let it fail naturally if Vagrant missing
- ✅ Execute API calls - let them fail naturally if Eryph down  
- ❌ Check if Vagrant is installed
- ❌ Test if Eryph is running
- ❌ Skip tests based on environment conditions

### What E2E Tests Validate
- Complete VM deployment lifecycle
- Real SSH connectivity
- Actual Vagrant command integration
- Plugin registration and recognition
- Error handling with real error conditions

### E2E Test Structure
```ruby
it 'completes full deployment lifecycle' do
  # NO environment checks - just run commands
  result = run_vagrant_command('up --provider=eryph')
  expect(result[:success]).to be(true), "vagrant up failed: #{result[:stderr]}"
  
  result = run_vagrant_command('ssh -c "echo Hello"')
  expect(result[:success]).to be(true), "SSH failed: #{result[:stderr]}"
  
  result = run_vagrant_command('destroy -f')
  expect(result[:success]).to be(true), "destroy failed: #{result[:stderr]}"
end
```

## Test Failure Philosophy

### Tests Should Fail When Environment is Wrong

- **Missing Vagrant** → E2E test fails with "command not found"
- **Eryph not running** → E2E test fails with connection error
- **Plugin not installed** → E2E test fails with "provider not found"

This is CORRECT behavior. Tests are contracts - they fail when the contract is broken.

### Only Skip for Platform Dependencies
```ruby
# ✅ Acceptable - different platforms
skip "Windows-only test" unless Gem.win_platform?

# ❌ Wrong - missing tooling  
skip "Eryph not running" unless eryph_available?
```

## TDD Approach - Test First!

### Every Bug Fix Must Have a Failing Test First

1. **Reproduce the bug** in a test
2. **See the test fail** 
3. **Fix the code**
4. **See the test pass**

### Recent Examples That Should Have Had Tests

**UNSET_VALUE Bug:**
```ruby
# This test should have existed and failed:
it 'handles setter methods with UNSET_VALUE' do
  config = described_class.new
  config.parent = "test-gene"  # Would crash without fix
  expect(config.parent).to eq("test-gene")
end
```

**Configuration Name Bug:**
```ruby
# This test should have existed and failed:
it 'defaults configuration_name to nil' do
  config = described_class.new
  config.finalize!
  expect(config.configuration_name).to be_nil  # Was 'default'
end
```

## Anti-Patterns to Avoid

### ❌ Testing Implementation Details
```ruby
# Wrong - tests private method
expect(config).to receive(:ensure_catlet_hash!)
```

### ❌ Mocking What We Don't Own
```ruby
# Wrong - mocking Vagrant internals
allow(Vagrant::Config).to receive(:new)
```

### ❌ Over-Mocking Unit Tests
```ruby
# Wrong - everything is mocked
allow(config).to receive(:parent).and_return("fake")
allow(config).to receive(:finalize!)
# What are we actually testing?
```

### ❌ Environment Defensive Programming in Tests
```ruby
# Wrong - tests checking environment
skip "Vagrant not installed" unless system("vagrant --version")
```

## Running Tests

```bash
# Fast development feedback
rake unit

# Full validation (assumes environment ready)  
rake e2e

# All tests
rake spec

# Install plugin for E2E testing
rake install
```

## Success Criteria

- Unit tests run in under 2 seconds
- Unit tests catch configuration bugs before they reach main
- E2E tests provide confidence in real-world usage
- Test failures are meaningful and actionable
- No false positives from over-mocking
- No false negatives from environment assumptions