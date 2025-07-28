@echo off
setlocal enabledelayedexpansion

if "%1"=="" (
    echo Usage: test.bat [command]
    echo.
    echo Available commands:
    echo   setup     - Build and install/reinstall the plugin
    echo   unit      - Run unit tests only ^(no Vagrant required^)
    echo   integration - Run full integration tests ^(requires Eryph^)
    echo   all       - Run setup + unit + integration tests
    echo   clean     - Clean up temporary files and uninstall plugin
    echo.
    echo Examples:
    echo   test.bat setup
    echo   test.bat integration
    echo   test.bat all
    exit /b 1
)

cd /d "%~dp0\.."

if "%1"=="setup" (
    echo Running plugin setup...
    ruby scripts\setup_plugin.rb
    goto :end
)

if "%1"=="unit" (
    echo Running unit tests...
    set VAGRANT_ERYPH_MOCK_CLIENT=true
    ruby tests\test_runner.rb
    goto :end
)

if "%1"=="integration" (
    echo Running integration tests...
    ruby scripts\run_integration_tests.rb
    goto :end
)

if "%1"=="all" (
    echo Running complete test suite...
    echo.
    echo Step 1/3: Plugin setup
    ruby scripts\setup_plugin.rb
    if !errorlevel! neq 0 (
        echo Plugin setup failed!
        exit /b 1
    )
    
    echo.
    echo Step 2/3: Unit tests
    set VAGRANT_ERYPH_MOCK_CLIENT=true
    ruby tests\test_runner.rb
    if !errorlevel! neq 0 (
        echo Unit tests failed!
        exit /b 1
    )
    
    echo.
    echo Step 3/3: Integration tests
    ruby scripts\run_integration_tests.rb
    goto :end
)

if "%1"=="clean" (
    echo Cleaning up...
    
    echo Uninstalling plugin...
    vagrant plugin uninstall vagrant-eryph 2>nul
    
    echo Removing gem files...
    del vagrant-eryph-*.gem 2>nul
    
    echo Removing temporary test files...
    rmdir /s /q tests\tmp 2>nul
    rmdir /s /q tmp 2>nul
    
    echo Cleanup completed.
    goto :end
)

echo Unknown command: %1
echo Run 'test.bat' for usage information.
exit /b 1

:end
echo.
echo Test command completed.