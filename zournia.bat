@echo off
title Zournia OS Launcher
echo ==============================================
echo   ZOURNIA OS - PLATFORM LAUNCHER
echo ==============================================
echo.

set ORIGINAL_DIR=%CD%
cd /d "D:\Daksh\Coding\Python\Personal Projects (fsociety)\Zournia\zournia_pc"

echo Setting environment path variables...
set PATH=D:\Daksh\Software\Windows\Flutter\src\flutter\flutter\bin;%PATH%

echo Verifying Flutter SDK installation...
call flutter --version
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Flutter SDK not found.
    cd /d "%ORIGINAL_DIR%"
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo Launching Zournia OS (Windows Desktop target)...
call flutter run -d windows
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Application failed with code %ERRORLEVEL%.
    pause
)

cd /d "%ORIGINAL_DIR%"
