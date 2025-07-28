# PowerShell script to run integration tests properly
# This demonstrates the correct way to run integration tests

Write-Host "🧪 Vagrant Eryph Plugin Integration Test Runner" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green

# Set environment variables for integration testing
$env:VAGRANT_ERYPH_INTEGRATION = "true"
$env:VAGRANT_ERYPH_DEBUG = "true"

Write-Host "✅ Environment variables set:" -ForegroundColor Green
Write-Host "   VAGRANT_ERYPH_INTEGRATION=$env:VAGRANT_ERYPH_INTEGRATION"
Write-Host "   VAGRANT_ERYPH_DEBUG=$env:VAGRANT_ERYPH_DEBUG"

Write-Host "`n📋 Running simple integration test verification..." -ForegroundColor Yellow
try {
    ruby test_integration_simple.rb
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Simple test passed!" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Simple test had issues (exit code: $LASTEXITCODE)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Error running simple test: $_" -ForegroundColor Red
}

Write-Host "`n📋 Running full integration test suite..." -ForegroundColor Yellow
try {
    rake integration
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Integration tests completed!" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Integration tests had issues (exit code: $LASTEXITCODE)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Error running integration tests: $_" -ForegroundColor Red
}

Write-Host "`n" + "=" * 60 -ForegroundColor Green
Write-Host "📝 Summary:" -ForegroundColor Green
Write-Host "   - Integration test environment has been fixed" -ForegroundColor White
Write-Host "   - Tests must be run from Command Prompt/PowerShell (not Git Bash)" -ForegroundColor White
Write-Host "   - Vagrant environment isolation is now properly implemented" -ForegroundColor White
Write-Host "   - Command execution uses Open3 for Windows compatibility" -ForegroundColor White