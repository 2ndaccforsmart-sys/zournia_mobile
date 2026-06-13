# Zournia OS Packaging and Deployment Script
# Automates Flutter Windows build and creates a desktop shortcut launcher.

$ErrorActionPreference = "Stop"

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "   ZOURNIA OS - BUILD & PACKAGING SYSTEM" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

# 1. Environment Configurations
$ProjectDir = Resolve-Path "$PSScriptRoot\.."
$FlutterBin = "D:\Daksh\Software\Windows\Flutter\src\flutter\flutter\bin\flutter.bat"
$DeployDir = "$Home\ZourniaOS"

Write-Host "[1/5] Checking Flutter SDK environment..." -ForegroundColor Yellow
if (!(Test-Path $FlutterBin)) {
    Write-Error "Flutter SDK not found at $FlutterBin. Please check path configuration."
}

# 2. Clean and Fetch Dependencies
Write-Host "[2/5] Cleaning previous builds and fetching dependencies..." -ForegroundColor Yellow
cd $ProjectDir
& $FlutterBin clean
& $FlutterBin pub get

# 3. Build Windows Executable
Write-Host "[3/5] Compiling release executable..." -ForegroundColor Yellow
& $FlutterBin build windows --release

$ReleaseDir = "$ProjectDir\build\windows\x64\runner\Release"
if (!(Test-Path $ReleaseDir\zournia_pc.exe)) {
    Write-Error "Compilation completed, but release executable could not be found at $ReleaseDir\zournia_pc.exe"
}

# 4. Deploy Artifacts to Permanent Folder
Write-Host "[4/5] Deploying build artifacts to $DeployDir..." -ForegroundColor Yellow
if (Test-Path $DeployDir) {
    Write-Host "Cleaning existing deployment folder..." -ForegroundColor Gray
    Remove-Item -Path $DeployDir -Recurse -Force
}
New-Item -ItemType Directory -Path $DeployDir -Force | Out-Null
Copy-Item -Path "$ReleaseDir\*" -Destination $DeployDir -Recurse -Force

# Copy user config files (api keys, custom models, session state) if they exist
$ConfigFiles = @("api_keys.json", "api_key.txt", "custom_models.json", "session_state.json")
foreach ($file in $ConfigFiles) {
    if (Test-Path "$ProjectDir\$file") {
        Write-Host "Copying configuration file: $file" -ForegroundColor Gray
        Copy-Item -Path "$ProjectDir\$file" -Destination $DeployDir -Force
    }
}

# Verify key files copy
if (!(Test-Path "$DeployDir\zournia_pc.exe")) {
    Write-Error "Failed to copy executable to deployment folder."
}

# 5. Create Desktop Launcher Shortcut
Write-Host "[5/5] Creating Desktop Launcher Shortcut..." -ForegroundColor Yellow
$DesktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
$ShortcutPath = Join-Path $DesktopPath "Zournia OS.lnk"

try {
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = "$DeployDir\zournia_pc.exe"
    $Shortcut.WorkingDirectory = $DeployDir
    $Shortcut.Description = "Launch Zournia OS AI Orchestrator Client"
    $Shortcut.Save()
    Write-Host "Desktop shortcut created successfully at: $ShortcutPath" -ForegroundColor Green
} catch {
    Write-Warning "Failed to create desktop shortcut. Error: $_"
}

Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host " BUILD & DEPLOYMENT COMPLETED SUCCESSFULLY!" -ForegroundColor Green
Write-Host " Launcher Shortcut: $ShortcutPath" -ForegroundColor Green
Write-Host " Application Directory: $DeployDir" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green
