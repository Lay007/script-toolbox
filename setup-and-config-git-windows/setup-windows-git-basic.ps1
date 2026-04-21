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
    [string]$GitServerHost,

    [Parameter(Mandatory = $false)]
    [string]$GitServerSshUser = 'git',

    [Parameter(Mandatory = $false)]
    [string]$GitHostAlias,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 65535)]
    [int]$GitServerPort = 22,

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

    Set-Acl -Path $Path -AclObject $acl
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
            Write-Info "Installing Git via winget..."
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
                Write-Ok 'Git installation via winget completed.'
            } else {
                Write-WarnMsg "winget installation failed with exit code $($process.ExitCode)."
                if ($Mode -eq 'winget') {
                    throw "winget installation failed with exit code $($process.ExitCode)."
                }
            }
        } elseif ($Mode -eq 'winget') {
            throw 'winget.exe not found.'
        }
    }

    if ((-not $installed) -and ($Mode -in @('auto', 'local'))) {
        if (-not $InstallerPath) {
            if ($Mode -eq 'local') {
                throw 'InstallMode=local requires -LocalInstallerPath.'
            }
        } else {
            if (-not (Test-Path $InstallerPath -PathType Leaf)) {
                throw "Local installer not found: $InstallerPath"
            }

            Write-Info "Installing Git via local installer..."
            $installerArgs = @('/VERYSILENT', '/NORESTART', '/NOCANCEL', '/SP-', '/SUPPRESSMSGBOXES', '/CLOSEAPPLICATIONS', '/RESTARTAPPLICATIONS')
            $process = Start-Process -FilePath $InstallerPath -ArgumentList $installerArgs -Wait -PassThru -WindowStyle Hidden
            if ($process.ExitCode -eq 0) {
                $installed = $true
                Write-Ok 'Git installation via local installer completed.'
            } else {
                throw "Local Git installer failed with exit code $($process.ExitCode)."
            }
        }
    }

    Add-GitToCurrentPath
    $gitExe = Resolve-GitExe
    if (-not $gitExe) {
        throw 'Git installation appears to have completed, but git.exe was not found.'
    }

    return $gitExe
}

function Get-KeyText {
    param(
        [string]$PathValue,
        [string]$RawValue,
        [string]$Description
    )

    if ($PathValue) {
        return [System.IO.File]::ReadAllText((Resolve-Path $PathValue), [System.Text.Encoding]::UTF8)
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

function Normalize-TextContent {
    param([string]$Content)

    if ($null -eq $Content) {
        return $null
    }

    $normalized = ($Content -replace "`r`n", "`n").Trim()
    if (-not $normalized.EndsWith("`n")) {
        $normalized += "`n"
    }
    return $normalized
}

function Write-ManagedTextFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][System.Security.Principal.NTAccount]$UserAccount,
        [Parameter(Mandatory = $false)][switch]$AllowOverwrite
    )

    $newContent = Normalize-TextContent -Content $Content
    if (Test-Path $Path) {
        $existingContent = Normalize-TextContent -Content ([System.IO.File]::ReadAllText($Path))
        if ($existingContent -eq $newContent) {
            Set-RestrictedAcl -Path $Path -UserAccount $UserAccount -IsDirectory $false
            Write-Ok "File already up to date: $Path"
            return
        }

        if (-not $AllowOverwrite) {
            throw "File already exists and differs: $Path. Re-run with -Force to overwrite."
        }

        $backupPath = "$Path.bak"
        Copy-Item -Path $Path -Destination $backupPath -Force
        Write-WarnMsg "Existing file was backed up: $backupPath"
    }

    Write-TextFileNormalized -Path $Path -Content $newContent
    Set-RestrictedAcl -Path $Path -UserAccount $UserAccount -IsDirectory $false
    Write-Ok "Wrote file: $Path"
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

function Invoke-GitConfigUnsetAllIfExists {
    param(
        [string]$GitExe,
        [string]$ConfigFile,
        [string]$Key
    )

    & $GitExe config --file $ConfigFile --unset-all $Key 2>$null
    $global:LASTEXITCODE = 0
}

function Get-InteractiveValue {
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [string]$DefaultValue
    )

    if ($DefaultValue) {
        $value = Read-Host "$Prompt [$DefaultValue]"
        if ([string]::IsNullOrWhiteSpace($value)) {
            return $DefaultValue
        }
        return $value.Trim()
    }

    while ($true) {
        $value = Read-Host $Prompt
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }
        Write-WarnMsg 'Value cannot be empty.'
    }
}

function Update-ManagedSshConfigBlock {
    param(
        [Parameter(Mandatory = $true)][string]$ConfigPath,
        [Parameter(Mandatory = $true)][System.Security.Principal.NTAccount]$UserAccount,
        [Parameter(Mandatory = $true)][string]$ManagedId,
        [Parameter(Mandatory = $true)][string]$BlockContent
    )

    $beginMarker = "# BEGIN managed by setup-windows-git-basic.ps1 : $ManagedId"
    $endMarker = "# END managed by setup-windows-git-basic.ps1 : $ManagedId"
    $managedBlock = @(
        $beginMarker,
        $BlockContent.TrimEnd(),
        $endMarker,
        ''
    ) -join "`n"

    $existing = ''
    if (Test-Path $ConfigPath) {
        $existing = [System.IO.File]::ReadAllText($ConfigPath)
    }

    $pattern = [regex]::Escape($beginMarker) + '.*?' + [regex]::Escape($endMarker) + '(\r?\n)?'
    if ([regex]::IsMatch($existing, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
        $updated = [regex]::Replace($existing, $pattern, $managedBlock, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    } else {
        if ($existing -and -not $existing.EndsWith("`n")) {
            $existing += "`n"
        }
        if ($existing -and -not $existing.EndsWith("`n`n")) {
            $existing += "`n"
        }
        $updated = $existing + $managedBlock
    }

    Write-TextFileNormalized -Path $ConfigPath -Content $updated
    Set-RestrictedAcl -Path $ConfigPath -UserAccount $UserAccount -IsDirectory $false
    Write-Ok "Updated SSH config: $ConfigPath"
}

Require-Administrator

if (-not $PSBoundParameters.ContainsKey('SshPrivateKeyPath') -and -not $PSBoundParameters.ContainsKey('SshPrivateKey')) {
    throw "Provide either -SshPrivateKeyPath or -SshPrivateKey."
}

if ($PSBoundParameters.ContainsKey('SshPublicKeyPath') -and $PSBoundParameters.ContainsKey('SshPublicKey')) {
    throw "Specify either -SshPublicKeyPath or -SshPublicKey, not both."
}

$GitServerHost = Get-InteractiveValue -Prompt 'Enter Git server hostname (for example: gitlab.example.com)' -DefaultValue $GitServerHost
if (-not $GitHostAlias) {
    $GitHostAlias = $GitServerHost
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
Write-Info "Writing SSH private key to $privateKeyFile ..."
Write-ManagedTextFile -Path $privateKeyFile -Content $privateKeyText -UserAccount $userObject.Account -AllowOverwrite:$Force

$publicKeyFile = Join-Path $sshDir 'id_ed25519.pub'
$publicKeyText = Get-KeyText -PathValue $SshPublicKeyPath -RawValue $SshPublicKey -Description 'SshPublicKey'

if ($publicKeyText) {
    Write-Info "Writing SSH public key to $publicKeyFile ..."
    Write-ManagedTextFile -Path $publicKeyFile -Content $publicKeyText -UserAccount $userObject.Account -AllowOverwrite:$Force
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
            Write-Info 'Generating public key from private key...'
            $generatedPublic = & $sshKeygen -y -f $privateKeyFile 2>$null
            if ($LASTEXITCODE -eq 0 -and $generatedPublic) {
                Write-ManagedTextFile -Path $publicKeyFile -Content $generatedPublic -UserAccount $userObject.Account -AllowOverwrite:$Force
                Write-Ok "Public key generated: $publicKeyFile"
            } else {
                Write-WarnMsg 'Could not generate public key automatically. This can happen with passphrase-protected keys.'
            }
        } catch {
            Write-WarnMsg "Could not generate public key automatically: $($_.Exception.Message)"
        }
    } else {
        Write-WarnMsg 'ssh-keygen.exe not found, skipping automatic public key generation.'
    }
}

$knownHostsFile = Join-Path $sshDir 'known_hosts'
if (-not (Test-Path $knownHostsFile)) {
    New-Item -ItemType File -Path $knownHostsFile -Force | Out-Null
}
Set-RestrictedAcl -Path $knownHostsFile -UserAccount $userObject.Account -IsDirectory $false

$sshConfigFile = Join-Path $sshDir 'config'
if (-not (Test-Path $sshConfigFile)) {
    New-Item -ItemType File -Path $sshConfigFile -Force | Out-Null
}
Set-RestrictedAcl -Path $sshConfigFile -UserAccount $userObject.Account -IsDirectory $false

$hostPatterns = if ($GitHostAlias -and ($GitHostAlias -ne $GitServerHost)) { "$GitHostAlias $GitServerHost" } else { $GitServerHost }
$sshBlock = @"
Host $hostPatterns
    HostName $GitServerHost
    User $GitServerSshUser
    Port $GitServerPort
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    PreferredAuthentications publickey
"@
Update-ManagedSshConfigBlock -ConfigPath $sshConfigFile -UserAccount $userObject.Account -ManagedId $GitHostAlias -BlockContent $sshBlock

$gitConfigFile = Join-Path $profilePath '.gitconfig'
if (-not (Test-Path $gitConfigFile)) {
    New-Item -ItemType File -Path $gitConfigFile -Force | Out-Null
}
Set-RestrictedAcl -Path $gitConfigFile -UserAccount $userObject.Account -IsDirectory $false

Write-Info 'Configuring Git settings...'
Invoke-GitConfigSet -GitExe $gitExe -ConfigFile $gitConfigFile -Key 'user.name' -Value $GitUserName
Invoke-GitConfigSet -GitExe $gitExe -ConfigFile $gitConfigFile -Key 'user.email' -Value $GitUserEmail
Invoke-GitConfigSet -GitExe $gitExe -ConfigFile $gitConfigFile -Key 'init.defaultBranch' -Value $DefaultBranch
Invoke-GitConfigSet -GitExe $gitExe -ConfigFile $gitConfigFile -Key 'fetch.prune' -Value 'true'
Invoke-GitConfigSet -GitExe $gitExe -ConfigFile $gitConfigFile -Key 'core.autocrlf' -Value $AutoCrlf
Invoke-GitConfigSet -GitExe $gitExe -ConfigFile $gitConfigFile -Key 'push.default' -Value 'simple'
Invoke-GitConfigSet -GitExe $gitExe -ConfigFile $gitConfigFile -Key 'rebase.autoStash' -Value 'true'
Invoke-GitConfigUnsetAllIfExists -GitExe $gitExe -ConfigFile $gitConfigFile -Key 'core.sshCommand'

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
            Write-Info 'Installing Git LFS...'
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
            Write-WarnMsg 'winget.exe not found. Skipping Git LFS installation.'
        }
    }

    $gitLfsCmd = Get-Command git-lfs.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue
    if ($gitLfsCmd) {
        & $gitExe lfs install
        if ($LASTEXITCODE -eq 0) {
            Write-Ok 'Git LFS initialized.'
        } else {
            Write-WarnMsg 'Git LFS was installed, but initialization returned a non-zero exit code.'
        }
    }
}

Write-Ok 'Git basic setup completed.'
Write-Host ''
Write-Host 'Summary:' -ForegroundColor White
Write-Host "  Windows user     : $Username"
Write-Host "  Git user.name    : $GitUserName"
Write-Host "  Git user.email   : $GitUserEmail"
Write-Host "  Git server host  : $GitServerHost"
Write-Host "  Git SSH user     : $GitServerSshUser"
Write-Host "  SSH host alias   : $GitHostAlias"
Write-Host "  SSH config file  : $sshConfigFile"
Write-Host "  Private key file : $privateKeyFile"
Write-Host "  Public key file  : $publicKeyFile"
Write-Host "  Git config file  : $gitConfigFile"
Write-Host ''
Write-Host 'Recommended checks:' -ForegroundColor White
Write-Host "  ssh -F `"$sshConfigFile`" -T $GitHostAlias"
Write-Host "  git config --file `"$gitConfigFile`" --list"
