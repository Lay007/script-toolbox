[CmdletBinding()]
param(
    [string]$ReleaseHistoryUrl = 'https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-history',
    [string]$BootstrapperOutputDir = (Join-Path $env:TEMP ('vs2026-buildtools-' + [guid]::NewGuid().ToString('N'))),
    [string]$BootstrapperFileName = 'vs_BuildTools.exe',
    [string]$InstallPath,
    [string[]]$AdditionalWorkloads = @(),
    [switch]$IncludeRecommended,
    [switch]$KeepBootstrapper,
    [switch]$SkipSignatureCheck,
    [switch]$DownloadOnly,
    [int]$VerificationTimeoutSeconds = 180
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info([string]$Message) { Write-Host ("[INFO] {0}" -f $Message) }
function Write-Ok([string]$Message)   { Write-Host ("[ OK ] {0}" -f $Message) }
function Write-Warn([string]$Message) { Write-Warning $Message }
function Throw-Terminating([string]$Message) { throw $Message }

function Test-CommandExists {
    param([Parameter(Mandatory)][string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -ne $cmd) { return $cmd.Source }
    return $null
}

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter()][string[]]$ArgumentList = @(),
        [switch]$UseStartProcess
    )

    Write-Info ("Running: {0} {1}" -f $FilePath, ($ArgumentList -join ' '))

    if ($UseStartProcess) {
        $proc = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -Wait -PassThru -NoNewWindow
        $exitCode = $proc.ExitCode
    }
    else {
        & $FilePath @ArgumentList
        if (Test-Path Variable:LASTEXITCODE) {
            $exitCode = $LASTEXITCODE
        }
        else {
            $exitCode = 0
        }
    }

    if ($null -eq $exitCode) {
        $exitCode = 0
    }

    if ($exitCode -ne 0) {
        Throw-Terminating (("Command failed with exit code {0}: {1} {2}") -f $exitCode, $FilePath, ($ArgumentList -join ' '))
    }
}

function Ensure-Directory {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        $null = New-Item -ItemType Directory -Path $Path -Force
    }
}

function Download-TextFile {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$OutFile
    )

    $iwr = Test-CommandExists -Name 'Invoke-WebRequest'
    if ($iwr) {
        Write-Info ("Downloading text via Invoke-WebRequest: {0}" -f $Url)
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
        return
    }

    $curl = Test-CommandExists -Name 'curl.exe'
    if ($curl) {
        Write-Info ("Downloading text via curl.exe: {0}" -f $Url)
        Invoke-ExternalCommand -FilePath $curl -ArgumentList @('-L', '--fail', '--output', $OutFile, $Url)
        return
    }

    Throw-Terminating 'Neither Invoke-WebRequest nor curl.exe is available to download the release history page.'
}

function Get-BuildToolsDirectUrlFromReleaseHistory {
    param([Parameter(Mandatory)][string]$ReleaseHistoryUrl)

    $tempHtml = Join-Path $env:TEMP ('vs2026-release-history-' + [guid]::NewGuid().ToString('N') + '.html')
    try {
        Download-TextFile -Url $ReleaseHistoryUrl -OutFile $tempHtml
        $html = Get-Content -LiteralPath $tempHtml -Raw

        if ($html -match '<title>.*Bing.*</title>' -or $html -match 'Bnp\.Global\.RawRequestURL') {
            Throw-Terminating 'Release history request was redirected to Bing or another unexpected page. Check proxy/filtering on this server.'
        }

        $regex = 'https://download\.visualstudio\.microsoft\.com/download/[^\s"''<>]+/vs_(?:B|b)uild[Tt]ools\.exe'
        $matches = [regex]::Matches($html, $regex, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

        if ($matches.Count -eq 0) {
            Throw-Terminating 'Could not find a direct Build Tools bootstrapper URL on the Visual Studio 2026 Release History page.'
        }

        $urls = New-Object System.Collections.Generic.List[string]
        foreach ($m in $matches) {
            if (-not $urls.Contains($m.Value)) {
                [void]$urls.Add($m.Value)
            }
        }

        $selectedUrl = $urls[0]
        Write-Ok ("Resolved direct Build Tools URL from Release History: {0}" -f $selectedUrl)
        return $selectedUrl
    }
    finally {
        if (Test-Path -LiteralPath $tempHtml) {
            Remove-Item -LiteralPath $tempHtml -Force -ErrorAction SilentlyContinue
        }
    }
}

function Test-BootstrapperLooksValid {
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$SkipSignatureCheck
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    $file = Get-Item -LiteralPath $Path
    if ($file.Length -lt 500KB) {
        Write-Warn ("Bootstrapper file is unexpectedly small: {0} bytes" -f $file.Length)
        return $false
    }

    $preview = ''
    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        $take = [Math]::Min($bytes.Length, 512)
        $preview = [System.Text.Encoding]::ASCII.GetString($bytes, 0, $take)
    }
    catch {
        Write-Warn ("Could not read downloaded file preview: {0}" -f $_.Exception.Message)
    }

    if ($preview -match '<!doctype html' -or $preview -match '<html' -or $preview -match '<title>.*Bing') {
        Write-Warn 'Downloaded file appears to be HTML, not an executable bootstrapper.'
        return $false
    }

    if (-not $SkipSignatureCheck) {
        try {
            $sig = Get-AuthenticodeSignature -FilePath $Path
            if ($sig.Status -ne 'Valid') {
                Write-Warn ("Bootstrapper signature is not valid: {0}" -f $sig.Status)
                return $false
            }
        }
        catch {
            Write-Warn ("Could not verify Authenticode signature: {0}" -f $_.Exception.Message)
            return $false
        }
    }

    return $true
}

function Download-Bootstrapper {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$OutFile,
        [switch]$SkipSignatureCheck
    )

    Ensure-Directory -Path (Split-Path -Parent $OutFile)

    $methods = @('Invoke-WebRequest', 'BITS', 'curl.exe')
    $downloaded = $false

    foreach ($method in $methods) {
        if (Test-Path -LiteralPath $OutFile) {
            Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
        }

        try {
            switch ($method) {
                'Invoke-WebRequest' {
                    Write-Info 'Trying download via Invoke-WebRequest'
                    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
                }
                'BITS' {
                    if (-not (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue)) {
                        Write-Info 'BITS is not available. Skipping.'
                        continue
                    }
                    Write-Info 'Trying download via BITS'
                    Start-BitsTransfer -Source $Url -Destination $OutFile
                }
                'curl.exe' {
                    $curl = Test-CommandExists -Name 'curl.exe'
                    if (-not $curl) {
                        Write-Info 'curl.exe is not available. Skipping.'
                        continue
                    }
                    Write-Info 'Trying download via curl.exe'
                    Invoke-ExternalCommand -FilePath $curl -ArgumentList @('-L', '--fail', '--output', $OutFile, $Url)
                }
            }

            if (Test-BootstrapperLooksValid -Path $OutFile -SkipSignatureCheck:$SkipSignatureCheck) {
                $downloaded = $true
                Write-Ok ("Bootstrapper downloaded to: {0}" -f $OutFile)
                break
            }
        }
        catch {
            Write-Warn ("Download via {0} failed: {1}" -f $method, $_.Exception.Message)
        }
    }

    if (-not $downloaded) {
        Throw-Terminating 'Failed to download a valid Visual Studio Build Tools bootstrapper from the resolved direct URL.'
    }
}

function Get-VsWherePath {
    $pf86 = [Environment]::GetFolderPath('ProgramFilesX86')
    $pf = [Environment]::GetFolderPath('ProgramFiles')
    $candidates = @(
        (Join-Path $pf86 'Microsoft Visual Studio\Installer\vswhere.exe'),
        (Join-Path $pf 'Microsoft Visual Studio\Installer\vswhere.exe')
    )

    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) { return $c }
    }

    $cmd = Get-Command vswhere.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Install-BuildTools {
    param(
        [Parameter(Mandatory)][string]$BootstrapperPath,
        [string]$InstallPath,
        [string[]]$AdditionalWorkloads,
        [switch]$IncludeRecommended
    )

    $args = @(
        'install',
        '--quiet',
        '--wait',
        '--norestart',
        '--nocache',
        '--add', 'Microsoft.VisualStudio.Workload.NativeDesktop'
    )

    if ($IncludeRecommended) {
        $args += '--includeRecommended'
    }

    if ($InstallPath) {
        $args += @('--installPath', $InstallPath)
    }

    foreach ($workload in $AdditionalWorkloads) {
        if ([string]::IsNullOrWhiteSpace($workload)) { continue }
        $args += @('--add', $workload.Trim())
    }

    Invoke-ExternalCommand -FilePath $BootstrapperPath -ArgumentList $args -UseStartProcess
}

function Get-InstallationEvidence {
    param([string]$VsWherePath)

    $result = [ordered]@{
        VsWherePath = $VsWherePath
        InstallationJson = $null
        InstallationPath = $null
        DisplayName = $null
        MSBuildPaths = @()
        ClPaths = @()
        CimInstances = @()
    }

    if ($VsWherePath) {
        try {
            $jsonRaw = & $VsWherePath -products * -all -format json 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace(($jsonRaw | Out-String))) {
                $instances = $jsonRaw | ConvertFrom-Json
                if ($instances) {
                    $result.InstallationJson = $jsonRaw
                    $first = @($instances)[0]
                    if ($first.PSObject.Properties.Name -contains 'installationPath') {
                        $result.InstallationPath = $first.installationPath
                    }
                    if ($first.PSObject.Properties.Name -contains 'displayName') {
                        $result.DisplayName = $first.displayName
                    }
                }
            }
        }
        catch {
            Write-Warn ("vswhere JSON query failed: {0}" -f $_.Exception.Message)
        }

        try {
            $msbuildFound = & $VsWherePath -products * -latest -find 'MSBuild\**\Bin\MSBuild.exe' 2>$null
            if ($LASTEXITCODE -eq 0 -and $msbuildFound) {
                $result.MSBuildPaths = @($msbuildFound | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            }
        }
        catch {
            Write-Warn ("vswhere MSBuild query failed: {0}" -f $_.Exception.Message)
        }

        try {
            $clFound = & $VsWherePath -products * -latest -find 'VC\Tools\MSVC\**\bin\Hostx64\x64\cl.exe' 2>$null
            if ($LASTEXITCODE -eq 0 -and $clFound) {
                $result.ClPaths = @($clFound | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            }
        }
        catch {
            Write-Warn ("vswhere cl.exe query failed: {0}" -f $_.Exception.Message)
        }
    }

    try {
        $cim = Get-CimInstance MSFT_VSInstance -Namespace root/cimv2/vs -ErrorAction Stop
        if ($cim) {
            $result.CimInstances = @($cim)
            if (-not $result.InstallationPath) {
                $firstCim = $result.CimInstances[0]
                if ($firstCim.PSObject.Properties.Name -contains 'InstallLocation') {
                    $result.InstallationPath = $firstCim.InstallLocation
                }
                if (-not $result.DisplayName -and $firstCim.PSObject.Properties.Name -contains 'DisplayName') {
                    $result.DisplayName = $firstCim.DisplayName
                }
            }
        }
    }
    catch {
        Write-Info 'CIM namespace root/cimv2/vs is not available or returned no data.'
    }

    return [pscustomobject]$result
}

function Wait-ForInstallationEvidence {
    param(
        [string]$VsWherePath,
        [int]$TimeoutSeconds = 180
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $attempt = 0

    do {
        $attempt++
        $evidence = Get-InstallationEvidence -VsWherePath $VsWherePath

        if ($evidence.MSBuildPaths.Count -gt 0 -or $evidence.ClPaths.Count -gt 0 -or $evidence.CimInstances.Count -gt 0 -or $evidence.InstallationPath) {
            return $evidence
        }

        if ((Get-Date) -ge $deadline) { break }
        Write-Info ("Waiting for Build Tools registration to become visible (attempt {0})..." -f $attempt)
        Start-Sleep -Seconds 5
    } while ($true)

    return $evidence
}

Write-Host '=== Visual Studio 2026 Build Tools installer ==='

$winget = Test-CommandExists -Name 'winget.exe'
if ($winget) {
    Write-Ok ("winget found: {0}" -f $winget)
}
else {
    Write-Warn 'winget was not found. This script does not require winget for the actual installation, but the system may be missing Windows Package Manager.'
}

Ensure-Directory -Path $BootstrapperOutputDir
$bootstrapperPath = Join-Path $BootstrapperOutputDir $BootstrapperFileName

$directUrl = Get-BuildToolsDirectUrlFromReleaseHistory -ReleaseHistoryUrl $ReleaseHistoryUrl
Download-Bootstrapper -Url $directUrl -OutFile $bootstrapperPath -SkipSignatureCheck:$SkipSignatureCheck

if ($DownloadOnly) {
    Write-Ok ("DownloadOnly requested. Bootstrapper saved to: {0}" -f $bootstrapperPath)
    return
}

Install-BuildTools -BootstrapperPath $bootstrapperPath -InstallPath $InstallPath -AdditionalWorkloads $AdditionalWorkloads -IncludeRecommended:$IncludeRecommended

$vswhere = Get-VsWherePath
if ($vswhere) {
    Write-Info ("Checking installation via vswhere: {0}" -f $vswhere)
}
else {
    Write-Warn 'vswhere.exe was not found. Falling back to CIM/WMI detection only.'
}

$evidence = Wait-ForInstallationEvidence -VsWherePath $vswhere -TimeoutSeconds $VerificationTimeoutSeconds

if ($evidence.DisplayName) {
    Write-Ok ("Detected product: {0}" -f $evidence.DisplayName)
}
if ($evidence.InstallationPath) {
    Write-Ok ("Installation path: {0}" -f $evidence.InstallationPath)
}
if ($evidence.MSBuildPaths.Count -gt 0) {
    Write-Ok ("MSBuild found: {0}" -f ($evidence.MSBuildPaths -join '; '))
}
if ($evidence.ClPaths.Count -gt 0) {
    Write-Ok ("cl.exe found: {0}" -f ($evidence.ClPaths -join '; '))
}
if ($evidence.CimInstances.Count -gt 0) {
    Write-Ok ("CIM detected {0} Visual Studio instance(s)." -f $evidence.CimInstances.Count)
}

if (-not $evidence.InstallationPath -and $evidence.MSBuildPaths.Count -eq 0 -and $evidence.ClPaths.Count -eq 0 -and $evidence.CimInstances.Count -eq 0) {
    Write-Warn 'Installer finished, but no Build Tools evidence was found via vswhere or CIM/WMI within the verification timeout. The installation may still have succeeded; verify in Visual Studio Installer or Installed Apps.'
}
else {
    Write-Ok 'Visual Studio 2026 Build Tools setup completed and verification found installation evidence.'
}

if (-not $KeepBootstrapper) {
    try {
        Remove-Item -LiteralPath $BootstrapperOutputDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Info ("Temporary download directory removed: {0}" -f $BootstrapperOutputDir)
    }
    catch {
        Write-Warn ("Could not remove temporary directory: {0}" -f $_.Exception.Message)
    }
}
else {
    Write-Info ("Bootstrapper kept at: {0}" -f $bootstrapperPath)
}
