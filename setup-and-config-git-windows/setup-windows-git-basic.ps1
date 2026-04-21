[CmdletBinding(DefaultParameterSetName = 'FromPrivateKeyPath')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Username,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$GitUserName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$GitUserEmail,

    [Parameter(Mandatory = $true, ParameterSetName = 'FromPrivateKeyPath')]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$SshPrivateKeyPath,

    [Parameter(Mandatory = $true, ParameterSetName = 'FromPrivateKeyString')]
    [ValidateNotNullOrEmpty()]
    [string]$SshPrivateKey,

    [Parameter(Mandatory = $false)]
    [string]$SshPublicKeyPath,

    [Parameter(Mandatory = $false)]
    [string]$SshPublicKey,

    [Parameter(Mandatory = $false)]
    [ValidateSet('auto', 'winget', 'local', 'skip')]
    [string]$InstallMode = 'auto',

    [Parameter(Mandatory = $false)]
    [string]$LocalInstallerPath,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$GitPackageId = 'Git.Git',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$DefaultBranch = 'main',

    [Parameter(Mandatory = $false)]
    [ValidateSet('rebase', 'merge')]
    [string]$PullMode = 'rebase',

    [Parameter(Mandatory = $false)]
    [ValidateSet('false', 'true', 'input')]
    [string]$AutoCrlf = 'false',

    [Parameter(Mandatory = $false)]
    [switch]$EnableCredentialManager = $true,

    [Parameter(Mandatory = $false)]
    [switch]$InstallGitLfs,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Write-Info([string]$Message) {
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-WarnMsg([string]$Message) {
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Ok([string]$Message) {
    Write-Host "[ OK ] $Message" -ForegroundColor Green
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Require-Administrator {
    if (-not (Test-IsAdministrator)) {
        throw "Run this script from an elevated PowerShell session (Run as Administrator)."
    }
}

function Resolve-UserObject {
    param([string]$Name)

    try {
        $localUser = Get-LocalUser -Name $Name -ErrorAction Stop
        $sid = New-Object System.Security.Principal.SecurityIdentifier($localUser.SID.Value)
        $account = $sid.Translate([System.Security.Principal.NTAccount])
        [pscustomobject]@{
            Name = $Name
            Account = $account
            Sid = $sid
            IsLocal = $true
        }
        return
    } catch {
    }

    try {
        $account = New-Object System.Security.Principal.NTAccount($Name)
        $sid = $account.Translate([System.Security.Principal.SecurityIdentifier])
        [pscustomobject]@{
            Name = $Name
            Account = $account
            Sid = $sid
            IsLocal = $false
        }
        return
    } catch {
        throw "Unable to resolve user '$Name'. Create the account first and log in once if needed."
    }
}

function Resolve-UserProfilePath {
    param([System.Security.Principal.SecurityIdentifier]$Sid, [string]$FallbackUserName)

    $profileListPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
    $sidKey = Join-Path $profileListPath $Sid.Value

    if (Test-Path $sidKey) {
        try {
            $profileImagePath = (Get-ItemProperty -Path $sidKey -Name ProfileImagePath -ErrorAction Stop).ProfileImagePath
            if ($profileImagePath) {
                return [Environment]::ExpandEnvironmentVariables($profileImagePath)
            }
        } catch {
        }
    }

    return (Join-Path $env:SystemDrive ("Users\" + $FallbackUserName))
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Set-RestrictedAcl {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][System.Security.Principal.NTAccount]$UserAccount,
        [Parameter(Mandatory = $true)][bool]$IsDirectory
    )

    $adminsSid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
    $systemSid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18')

    $adminsAccount = $adminsSid.Translate([System.Security.Principal.NTAccount])
    $systemAccount = $systemSid.Translate([System.Security.Principal.NTAccount])

    if ($IsDirectory) {
        $acl = New-Object System.Security.AccessControl.DirectorySecurity
        $inheritanceFlags = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
    } else {
        $acl = New-Object System.Security.AccessControl.FileSecurity
        $inheritanceFlags = [System.Security.AccessControl.InheritanceFlags]::None
    }

    $propagationFlags = [System.Security.AccessControl.PropagationFlags]::None
    $fileSystemRights = [System.Security.AccessControl.FileSystemRights]::FullControl
    $accessType = [System.Security.AccessControl.AccessControlType]::Allow

    $acl.SetAccessRuleProtection($true, $false)
    $acl.SetOwner($UserAccount)

    foreach ($account in @($UserAccount, $adminsAccount, $systemAccount)) {
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $account,
            $fileSystemRights,
            $inheritanceFlags,
            $propagationFlags,
            $accessType
        )
        $acl.AddAccessRule($rule) | Out-Null
    }

    if ($IsDirectory) {
        Set-Acl -Path $Path -AclObject $acl
    } else {
        Set-Acl -Path $Path -AclObject $acl
    }
}

function Resolve-GitExe {
    $candidates = @(
        (Get-Command git.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
        "$env:ProgramFiles\Git\cmd\git.exe",
        "$env:ProgramFiles\Git\bin\git.exe",
        "$env:ProgramFiles(x86)\Git\cmd\git.exe",
        "$env:ProgramFiles(x86)\Git\bin\git.exe"
    ) | Where-Object { $_ }

    foreach ($candidate in $candidates | Select-Object -Unique) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    return $null
}

function Add-GitToCurrentPath {
    $gitCmdPath = Join-Path $env:ProgramFiles 'Git\cmd'
    $gitBinPath = Join-Path $env:ProgramFiles 'Git\usr\bin'
    foreach ($pathToAdd in @($gitCmdPath, $gitBinPath)) {
        if ((Test-Path $pathToAdd) -and (-not (($env:Path -split ';') -contains $pathToAdd))) {
            $env:Path = "$pathToAdd;$env:Path"
        }
    }
}

function Install-GitIfNeeded {
    param(
        [string]$Mode,
        [string]$PackageId,
        [string]$InstallerPath
    )

    $gitExe = Resolve-GitExe
    if ($gitExe) {
        Write-Ok "Git already installed: $gitExe"
        Add-GitToCurrentPath
        return $gitExe
    }

    if ($Mode -eq 'skip') {
        throw "Git is not installed and InstallMode=skip was specified."
    }

    $installed = $false

    if ($Mode -in @('auto', 'winget')) {
        $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
        if ($winget) {
            Write-Info "Installing Git with winget package '$PackageId'..."
            $args = @(
                'install',
                '--id', $PackageId,
                '-e',
                '--source', 'winget',
                '--accept-package-agreements',
                '--accept-source-agreements',
                '--disable-interactivity'
            )
            $process = Start-Process -FilePath $winget.Source -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
            if ($process.ExitCode -eq 0) {
                $installed = $true
                Write-Ok "Git installation via winget completed."
            } elseif ($Mode -eq 'winget') {
                throw "winget installation failed with exit code $($process.ExitCode)."
            } else {
                Write-WarnMsg "winget installation failed with exit code $($process.ExitCode). Will try fallback if available."
            }
        } elseif ($Mode -eq 'winget') {
            throw "winget.exe not found, but InstallMode=winget was specified."
        } else {
            Write-WarnMsg "winget.exe not found. Will try fallback if available."
        }
    }

    if (-not $installed -and $Mode -in @('auto', 'local')) {
        if (-not $InstallerPath) {
            if ($Mode -eq 'local') {
                throw "LocalInstallerPath is required when InstallMode=local."
            }
        } else {
            if (-not (Test-Path $InstallerPath -PathType Leaf)) {
                throw "Local installer not found: $InstallerPath"
            }

            Write-Info "Installing Git from local installer..."
            $installerArgs = @('/VERYSILENT', '/NORESTART', '/NOCANCEL', '/SP-', '/CLOSEAPPLICATIONS', '/RESTARTAPPLICATIONS')
            $process = Start-Process -FilePath $InstallerPath -ArgumentList $installerArgs -Wait -PassThru
            if ($process.ExitCode -eq 0) {
                $installed = $true
                Write-Ok "Git installation from local installer completed."
            } else {
                throw "Local installer failed with exit code $($process.ExitCode)."
            }
        }
    }

    $gitExe = Resolve-GitExe
    if (-not $gitExe) {
        throw "Git installation finished, but git.exe was not found."
    }

    Add-GitToCurrentPath
    return $gitExe
}

function Get-KeyText {
    param(
        [string]$PathValue,
        [string]$RawValue,
        [string]$Description
    )

    if ($PathValue -and $RawValue) {
        throw "Specify either ${Description}Path or ${Description}, not both."
    }

    if ($PathValue) {
        return Get-Content -Path $PathValue -Raw -Encoding UTF8
    }

    if ($RawValue) {
        return $RawValue
    }

    return $null
}

function Write-TextFileNormalized {
    param(
        [string]$Path,
        [string]$Content
    )

    $normalized = ($Content -replace "`r`n", "`n").Trim()
    if (-not $normalized.EndsWith("`n")) {
        $normalized += "`n"
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $normalized, $utf8NoBom)
}

function Invoke-GitConfigSet {
    param(
        [string]$GitExe,
        [string]$ConfigFile,
        [string]$Key,
        [string]$Value
    )

    & $GitExe config --file $ConfigFile $Key $Value
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to set git config '$Key'."
    }
}

Require-Administrator

if (-not $PSBoundParameters.ContainsKey('SshPrivateKeyPath') -and -not $PSBoundParameters.ContainsKey('SshPrivateKey')) {
    throw "Provide either -SshPrivateKeyPath or -SshPrivateKey."
}

if ($PSBoundParameters.ContainsKey('SshPublicKeyPath') -and $PSBoundParameters.ContainsKey('SshPublicKey')) {
    throw "Specify either -SshPublicKeyPath or -SshPublicKey, not both."
}

Write-Info "Resolving user '$Username'..."
$userObject = Resolve-UserObject -Name $Username
$profilePath = Resolve-UserProfilePath -Sid $userObject.Sid -FallbackUserName $Username
Ensure-Directory -Path $profilePath
Write-Ok "Profile path: $profilePath"

$gitExe = Install-GitIfNeeded -Mode $InstallMode -PackageId $GitPackageId -InstallerPath $LocalInstallerPath
Write-Info ("Using git: " + $gitExe)
& $gitExe --version

$sshDir = Join-Path $profilePath '.ssh'
Ensure-Directory -Path $sshDir
Set-RestrictedAcl -Path $sshDir -UserAccount $userObject.Account -IsDirectory $true

$privateKeyFile = Join-Path $sshDir 'id_ed25519'
$privateKeyText = Get-KeyText -PathValue $SshPrivateKeyPath -RawValue $SshPrivateKey -Description 'SshPrivateKey'
Write-Info "Writing SSH private key..."
Write-TextFileNormalized -Path $privateKeyFile -Content $privateKeyText
Set-RestrictedAcl -Path $privateKeyFile -UserAccount $userObject.Account -IsDirectory $false

$publicKeyFile = Join-Path $sshDir 'id_ed25519.pub'
$publicKeyText = Get-KeyText -PathValue $SshPublicKeyPath -RawValue $SshPublicKey -Description 'SshPublicKey'

if ($publicKeyText) {
    Write-Info "Writing SSH public key..."
    Write-TextFileNormalized -Path $publicKeyFile -Content $publicKeyText
    Set-RestrictedAcl -Path $publicKeyFile -UserAccount $userObject.Account -IsDirectory $false
} else {
    $sshKeygen = Get-Command ssh-keygen.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue
    if (-not $sshKeygen) {
        $sshKeygen = Join-Path $env:SystemRoot 'System32\OpenSSH\ssh-keygen.exe'
    }
    if (-not (Test-Path $sshKeygen)) {
        $sshKeygen = Join-Path $env:ProgramFiles 'Git\usr\bin\ssh-keygen.exe'
    }

    if (Test-Path $sshKeygen) {
        try {
            Write-Info "Generating public key from private key..."
            $generatedPublic = & $sshKeygen -y -f $privateKeyFile 2>$null
            if ($LASTEXITCODE -eq 0 -and $generatedPublic) {
                Write-TextFileNormalized -Path $publicKeyFile -Content $generatedPublic
                Set-RestrictedAcl -Path $publicKeyFile -UserAccount $userObject.Account -IsDirectory $false
                Write-Ok "Public key generated: $publicKeyFile"
            } else {
                Write-WarnMsg "Could not generate public key automatically. This can happen with passphrase-protected keys."
            }
        } catch {
            Write-WarnMsg "Could not generate public key automatically: $($_.Exception.Message)"
        }
    } else {
        Write-WarnMsg "ssh-keygen.exe not found, skipping automatic public key generation."
    }
}

$knownHostsFile = Join-Path $sshDir 'known_hosts'
if (-not (Test-Path $knownHostsFile)) {
    New-Item -ItemType File -Path $knownHostsFile -Force | Out-Null
}
Set-RestrictedAcl -Path $knownHostsFile -UserAccount $userObject.Account -IsDirectory $false

$gitConfigFile = Join-Path $profilePath '.gitconfig'
if (-not (Test-Path $gitConfigFile)) {
    New-Item -ItemType File -Path $gitConfigFile -Force | Out-Null
}
Set-RestrictedAcl -Path $gitConfigFile -UserAccount $userObject.Account -IsDirectory $false

Write-Info "Configuring Git settings..."
Invoke-GitConfigSet -GitExe $gitExe -ConfigFile $gitConfigFile -Key 'user.name' -Value $GitUserName
Invoke-GitConfigSet -GitExe $gitExe -ConfigFile $gitConfigFile -Key 'user.email' -Value $GitUserEmail
Invoke-GitConfigSet -GitExe $gitExe -ConfigFile $gitConfigFile -Key 'init.defaultBranch' -Value $DefaultBranch
Invoke-GitConfigSet -GitExe $gitExe -ConfigFile $gitConfigFile -Key 'fetch.prune' -Value 'true'
Invoke-GitConfigSet -GitExe $gitExe -ConfigFile $gitConfigFile -Key 'core.autocrlf' -Value $AutoCrlf
Invoke-GitConfigSet -GitExe $gitExe -ConfigFile $gitConfigFile -Key 'core.sshCommand' -Value ("ssh -i `"$privateKeyFile`" -o IdentitiesOnly=yes")
Invoke-GitConfigSet -GitExe $gitExe -ConfigFile $gitConfigFile -Key 'push.default' -Value 'simple'
Invoke-GitConfigSet -GitExe $gitExe -ConfigFile $gitConfigFile -Key 'rebase.autoStash' -Value 'true'

if ($PullMode -eq 'rebase') {
    Invoke-GitConfigSet -GitExe $gitExe -ConfigFile $gitConfigFile -Key 'pull.rebase' -Value 'true'
} else {
    Invoke-GitConfigSet -GitExe $gitExe -ConfigFile $gitConfigFile -Key 'pull.rebase' -Value 'false'
}

if ($EnableCredentialManager) {
    Invoke-GitConfigSet -GitExe $gitExe -ConfigFile $gitConfigFile -Key 'credential.helper' -Value 'manager-core'
}

if ($InstallGitLfs) {
    $gitLfsCmd = Get-Command git-lfs.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue
    if (-not $gitLfsCmd) {
        $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
        if ($winget) {
            Write-Info "Installing Git LFS..."
            $args = @(
                'install',
                '--id', 'GitHub.GitLFS',
                '-e',
                '--source', 'winget',
                '--accept-package-agreements',
                '--accept-source-agreements',
                '--disable-interactivity'
            )
            $process = Start-Process -FilePath $winget.Source -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
            if ($process.ExitCode -ne 0) {
                Write-WarnMsg "Git LFS installation failed with exit code $($process.ExitCode)."
            }
        } else {
            Write-WarnMsg "winget.exe not found. Skipping Git LFS installation."
        }
    }

    $gitLfsCmd = Get-Command git-lfs.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue
    if ($gitLfsCmd) {
        & $gitExe lfs install
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Git LFS initialized."
        } else {
            Write-WarnMsg "git lfs install returned exit code $LASTEXITCODE."
        }
    } else {
        Write-WarnMsg "git-lfs.exe not found after installation attempt."
    }
}

Write-Host ""
Write-Ok "Done."
Write-Host "Git config file : $gitConfigFile"
Write-Host "SSH directory   : $sshDir"
Write-Host "Private key     : $privateKeyFile"
if (Test-Path $publicKeyFile) {
    Write-Host "Public key      : $publicKeyFile"
}
Write-Host ""
Write-Host "Next checks:"
Write-Host "  git --version"
Write-Host "  git config --file `"$gitConfigFile`" --list"
Write-Host "  ssh -T git@github.com"
Write-Host "  ssh -T git@gitlab.com"
