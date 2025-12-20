<#
.SYNOPSIS
Auto Flutter + Android Install Script for Windows
#>

# ---------------- Helpers ----------------
function Log($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Err($msg) { Write-Host "[ERR] $msg" -ForegroundColor Red; exit 1 }

# ---------------- Check for commands ----------------
function Require-Command($cmd) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Err "Missing command: $cmd"
    }
}

# ---------------- Paths ----------------
$UserHome = [Environment]::GetFolderPath("UserProfile")
$FlutterHome = Join-Path $UserHome "flutter"
$AndroidSdkRoot = Join-Path $UserHome "AppData\Local\Android\Sdk"
$CmdlineTools = Join-Path $AndroidSdkRoot "cmdline-tools\latest"

# ---------------- Install Git if missing ----------------
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Log "Git not found. Installing Git..."
    # Requires Chocolatey
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Log "Installing Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = 
[System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object) 
System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }
    Log "Installing Git via Chocolatey..."
    choco install git -y
} else {
    Log "Git already installed."
}

# ---------------- Install Flutter SDK ----------------
if (-not (Test-Path "$FlutterHome\bin\flutter.bat")) {
    Log "Installing Flutter SDK..."
    git clone https://github.com/flutter/flutter.git -b stable $FlutterHome
} else {
    Log "Flutter already installed at $FlutterHome"
}

# Add Flutter to PATH (current session)
$env:Path = "$FlutterHome\bin;$env:Path"

# ---------------- Install Android Studio ----------------
if (-not (Test-Path "C:\Program Files\Android\Android Studio\bin\studio64.exe")) {
    Log "Installing Android Studio via Chocolatey..."
    choco install androidstudio -y
} else {
    Log "Android Studio already installed."
}

# ---------------- Install Android SDK command-line tools ----------------
if (-not (Test-Path $CmdlineTools)) {
    Log "Downloading Android command-line tools..."
    $TmpZip = "$env:TEMP\cmdline-tools.zip"
    Invoke-WebRequest -Uri 
"https://dl.google.com/android/repository/commandlinetools-win-9477386_latest.zip" -OutFile $TmpZip
    Expand-Archive $TmpZip -DestinationPath (Join-Path $AndroidSdkRoot "cmdline-tools")
    Rename-Item (Join-Path $AndroidSdkRoot "cmdline-tools\cmdline-tools") "latest"
}

# Add SDK tools to PATH (current session)
$env:Path = "$CmdlineTools\bin;$AndroidSdkRoot\platform-tools;$env:Path"

Require-Command sdkmanager

# ---------------- Install latest Android SDK ----------------
Log "Resolving latest Android SDK packages..."
$platforms = & sdkmanager --list | Select-String -Pattern 'platforms;android-[0-9]+' | ForEach-Object { 
$_.Matches[0].Value } | Sort-Object | Select-Object -Last 1
$buildTools = & sdkmanager --list | Select-String -Pattern 'build-tools;[0-9.]+' | ForEach-Object { 
$_.Matches[0].Value } | Sort-Object | Select-Object -Last 1

Log "Installing platform-tools, $platforms, $buildTools..."
& sdkmanager "platform-tools" $platforms $buildTools

# ---------------- Accept licenses ----------------
Log "Accepting all Android licenses..."
cmd /c "yes | sdkmanager --licenses"

# ---------------- Flutter config ----------------
flutter config --android-sdk $AndroidSdkRoot

Log "Installation completed!"
Write-Host "Run 'flutter doctor' to verify your setup."

