#!/bin/bash

# Cross-platform test runner for Vagrant Eryph plugin
# Works on Linux/macOS (though Eryph zero requires Windows)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

show_usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Available commands:"
    echo "  setup       - Build and install/reinstall the plugin"
    echo "  unit        - Run unit tests only (no Vagrant required)"
    echo "  integration - Run full integration tests (requires Eryph)"
    echo "  all         - Run setup + unit + integration tests"
    echo "  clean       - Clean up temporary files and uninstall plugin"
    echo ""
    echo "Examples:"
    echo "  $0 setup"
    echo "  $0 integration"
    echo "  $0 all"
    echo ""
    echo "Note: Integration tests require Eryph zero running on Windows with Hyper-V"
}

setup_plugin() {
    echo "Running plugin setup..."
    cd "$PROJECT_ROOT"
    ruby scripts/setup_plugin.rb
}

run_unit_tests() {
    echo "Running unit tests..."
    cd "$PROJECT_ROOT"
    export VAGRANT_ERYPH_MOCK_CLIENT=true
    ruby tests/test_runner.rb
}

run_integration_tests() {
    echo "Running integration tests..."
    cd "$PROJECT_ROOT"
    ruby scripts/run_integration_tests.rb
}

run_all_tests() {
    echo "Running complete test suite..."
    echo ""
    
    echo "Step 1/3: Plugin setup"
    setup_plugin
    
    echo ""
    echo "Step 2/3: Unit tests"
    run_unit_tests
    
    echo ""
    echo "Step 3/3: Integration tests"
    run_integration_tests
}

clean_up() {
    echo "Cleaning up..."
    cd "$PROJECT_ROOT"
    
    echo "Uninstalling plugin..."
    vagrant plugin uninstall vagrant-eryph 2>/dev/null || true
    
    echo "Removing gem files..."
    rm -f vagrant-eryph-*.gem
    
    echo "Removing temporary test files..."
    rm -rf tests/tmp tmp
    
    echo "Cleanup completed."
}

# Main command handling
case "${1:-}" in
    "setup")
        setup_plugin
        ;;
    "unit")
        run_unit_tests
        ;;
    "integration")
        run_integration_tests
        ;;
    "all")
        run_all_tests
        ;;
    "clean")
        clean_up
        ;;
    "")
        show_usage
        exit 1
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run '$0' for usage information."
        exit 1
        ;;
esac

echo ""
echo "Test command completed."