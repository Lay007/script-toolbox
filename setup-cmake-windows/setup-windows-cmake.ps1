[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$PackageId = 'Kitware.CMake',

    [Parameter(Mandatory = $false)]
    [switch]$ForceReinstall,

    [Parameter(Mandatory = $false)]
    [switch]$PassThruWingetLogs
)

$ErrorActionPreference = 'Stop'

function Write-Info([string]$Message) {
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "[ OK ] $Message" -ForegroundColor Green
}

function Write-WarnMsg([string]$Message) {
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Throw-Terminating([string]$Message) {
    throw $Message
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-CommandPath([string]$Name) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$ArgumentList,
        [switch]$IgnoreExitCode
    )

    Write-Info ("Running: {0} {1}" -f $FilePath, ($ArgumentList -join ' '))
    & $FilePath @ArgumentList
    $exitCode = $LASTEXITCODE
    if (-not $IgnoreExitCode -and $exitCode -ne 0) {
        Throw-Terminating (("Command failed with exit code {0}: {1} {2}") -f $exitCode, $FilePath, ($ArgumentList -join ' '))
    }
    return $exitCode
}

function Get-WingetPath {
    $winget = Get-CommandPath 'winget.exe'
    if ($winget) { return $winget }
    $winget = Get-CommandPath 'winget'
    if ($winget) { return $winget }
    Throw-Terminating 'winget is not available. Install App Installer / winget first.'
}

function Test-WingetPackageId {
    param(
        [Parameter(Mandatory = $true)][string]$WingetPath,
        [Parameter(Mandatory = $true)][string]$Id
    )

    $searchOutput = & $WingetPath search --id $Id --exact --source winget 2>&1 | Out-String
    if ($PassThruWingetLogs) {
        Write-Host $searchOutput
    }
    if ($LASTEXITCODE -ne 0) {
        return $false
    }
    return ($searchOutput -match [regex]::Escape($Id))
}

function Test-WingetInstalled {
    param(
        [Parameter(Mandatory = $true)][string]$WingetPath,
        [Parameter(Mandatory = $true)][string]$Id
    )

    $listOutput = & $WingetPath list --id $Id --exact --source winget 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        return $false
    }
    return ($listOutput -match [regex]::Escape($Id))
}

function Get-CMakeBinaryCandidate {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'CMake\bin\cmake.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'CMake\bin\cmake.exe')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    $cmdPath = Get-CommandPath 'cmake.exe'
    if ($cmdPath) { return $cmdPath }
    $cmdPath = Get-CommandPath 'cmake'
    if ($cmdPath) { return $cmdPath }
    return $null
}

if (-not (Test-IsAdmin)) {
    Throw-Terminating 'Run this script from an elevated PowerShell session (Run as Administrator).'
}

$wingetPath = Get-WingetPath
Write-Ok "winget found: $wingetPath"

if (-not (Test-WingetPackageId -WingetPath $wingetPath -Id $PackageId)) {
    Throw-Terminating "Package '$PackageId' was not found in winget source 'winget'. Run: winget search cmake"
}

if ((-not $ForceReinstall) -and (Test-WingetInstalled -WingetPath $wingetPath -Id $PackageId)) {
    Write-WarnMsg "$PackageId is already installed according to winget. Nothing to do. Use -ForceReinstall if you want to reinstall."
    exit 0
}

$installArgs = @(
    'install',
    '--id', $PackageId,
    '--exact',
    '--source', 'winget',
    '--accept-package-agreements',
    '--accept-source-agreements'
)

Invoke-ExternalCommand -FilePath $wingetPath -ArgumentList $installArgs

$cmakeExe = Get-CMakeBinaryCandidate
if (-not $cmakeExe) {
    Throw-Terminating 'CMake installation finished, but cmake.exe was not found. Reopen the terminal or check the install manually.'
}

$cmakeBin = Split-Path -Parent $cmakeExe
if ($env:Path -notmatch [regex]::Escape($cmakeBin)) {
    $env:Path = "$cmakeBin;$env:Path"
    Write-WarnMsg "Added '$cmakeBin' to PATH for the current session only. Open a new terminal to get the persistent PATH from the installer."
}

Write-Info "Using cmake binary: $cmakeExe"
& $cmakeExe --version
if ($LASTEXITCODE -ne 0) {
    Throw-Terminating 'CMake was found but did not return a version successfully.'
}

Write-Host ''
Write-Ok 'Done.'
Write-Host 'Recommended next steps:' -ForegroundColor Cyan
Write-Host '  1. Open a new terminal and run: cmake --version'
Write-Host '  2. For MSVC builds, first open a Visual Studio Native Tools prompt or initialize the MSVC environment.'
