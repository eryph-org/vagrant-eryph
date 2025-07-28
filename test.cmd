@echo off
echo Running Vagrant Eryph Plugin Test Suite
echo ==========================================

echo.
echo 1. Structure Tests
echo ------------------
call rake structure
if errorlevel 1 goto :error

echo.
echo 2. Unit Tests  
echo -------------
call rake unit
if errorlevel 1 goto :error

echo.
echo 3. Installation Tests
echo --------------------
call rake install
if errorlevel 1 goto :error

echo.
echo 4. Integration Tests (with plugin check)
echo ----------------------------------------
set VAGRANT_ERYPH_INTEGRATION=true
call rake integration
if errorlevel 1 goto :error

echo.
echo 5. E2E Tests
echo -----------
call rake e2e
if errorlevel 1 goto :error

echo.
echo ==========================================
echo ✅ ALL TESTS COMPLETED SUCCESSFULLY
echo ==========================================
goto :end

:error
echo.
echo ==========================================
echo ❌ TESTS FAILED - See output above
echo ==========================================
exit /b 1

:end