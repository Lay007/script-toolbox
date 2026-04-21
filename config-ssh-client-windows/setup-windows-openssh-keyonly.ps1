<#
.SYNOPSIS
Configures Windows OpenSSH Server for key-only SSH access for a specified local administrator account.

.DESCRIPTION
- Requires an explicit user name and an explicit public key (inline or via file).
- Creates the local user if needed.
- Adds the user to the built-in Administrators group using SID S-1-5-32-544.
- Adds the public key to C:\ProgramData\ssh\administrators_authorized_keys.
- Applies the required ACLs for Windows OpenSSH admin-key usage.
- Updates %ProgramData%\ssh\sshd_config safely before any Match blocks.
- Validates the config with sshd -t and restarts the sshd service.

.NOTES
Run from an elevated PowerShell session.
#>

[CmdletBinding(DefaultParameterSetName='File')]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Username,

    [Parameter()]
    [string]$FullName,

    [Parameter()]
    [string]$Description = 'SSH account (key-only)',

    [Parameter(ParameterSetName='Inline', Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$PublicKey,

    [Parameter(ParameterSetName='File', Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$PublicKeyPath,

    [Parameter()]
    [bool]$DisablePasswordAuthentication = $true,

    [Parameter()]
    [bool]$RestrictSshToUser = $true,

    [switch]$OpenFirewall,

    [switch]$SkipUserCreation,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Test-IsAdministrator {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($current)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-ValidatedPublicKey {
    param(
        [string]$InlineKey,
        [string]$Path,
        [string]$ParameterSetName
    )

    if ($ParameterSetName -eq 'File') {
        if (-not (Test-Path -LiteralPath $Path)) {
            throw "Public key file not found: $Path"
        }
        $key = (Get-Content -LiteralPath $Path -Raw).Trim()
    }
    else {
        $key = $InlineKey.Trim()
    }

    if ($key -notmatch '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521))\s+[A-Za-z0-9+/=]+(?:\s+.+)?$') {
        throw 'The supplied public key does not look like a valid OpenSSH public key.'
    }

    return $key
}

function Get-ConfigLines {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "sshd_config not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return [System.Collections.Generic.List[string]]::new()
    }

    $normalized = $raw -replace "`r`n", "`n"
    $arr = $normalized -split "`n"
    $list = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $arr) {
        [void]$list.Add($line)
    }
    return $list
}

function Save-ConfigLines {
    param(
        [string]$Path,
        [System.Collections.Generic.List[string]]$Lines
    )

    $text = ($Lines.ToArray() -join "`r`n").TrimEnd("`r", "`n") + "`r`n"
    Set-Content -LiteralPath $Path -Value $text -Encoding Ascii
}

function Get-FirstMatchIndex {
    param([System.Collections.Generic.List[string]]$Lines)

    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^(?i)\s*Match\s+') {
            return $i
        }
    }
    return $Lines.Count
}

function Set-GlobalDirective {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$Name,
        [string]$Value
    )

    $firstMatchIndex = Get-FirstMatchIndex -Lines $Lines

    for ($i = $firstMatchIndex - 1; $i -ge 0; $i--) {
        if ($Lines[$i] -match ('^(?i)\s*#?\s*' + [regex]::Escape($Name) + '\b')) {
            $Lines.RemoveAt($i)
            $firstMatchIndex--
        }
    }

    [void]$Lines.Insert($firstMatchIndex, "$Name $Value")
}

function Ensure-MatchGroupAdministratorsAuthorizedKeys {
    param([System.Collections.Generic.List[string]]$Lines)

    $matchIndex = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^(?i)\s*Match\s+Group\s+administrators\s*$') {
            $matchIndex = $i
            break
        }
    }

    if ($matchIndex -lt 0) {
        if ($Lines.Count -gt 0 -and $Lines[$Lines.Count - 1].Trim() -ne '') {
            [void]$Lines.Add('')
        }
        [void]$Lines.Add('Match Group administrators')
        [void]$Lines.Add('    AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys')
        return
    }

    $blockEnd = $Lines.Count
    for ($j = $matchIndex + 1; $j -lt $Lines.Count; $j++) {
        if ($Lines[$j] -match '^(?i)\s*Match\s+') {
            $blockEnd = $j
            break
        }
    }

    $authorizedLineIndex = -1
    for ($k = $matchIndex + 1; $k -lt $blockEnd; $k++) {
        if ($Lines[$k] -match '^(?i)\s*#?\s*AuthorizedKeysFile\b') {
            $authorizedLineIndex = $k
            break
        }
    }

    if ($authorizedLineIndex -ge 0) {
        $Lines[$authorizedLineIndex] = '    AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys'
    }
    else {
        [void]$Lines.Insert($matchIndex + 1, '    AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys')
    }
}

function Ensure-UserExists {
    param(
        [string]$Name,
        [string]$FullName,
        [string]$Description,
        [switch]$SkipCreation
    )

    $existing = Get-LocalUser -Name $Name -ErrorAction SilentlyContinue
    if ($existing) {
        return $existing
    }

    if ($SkipCreation) {
        throw "Local user '$Name' does not exist and -SkipUserCreation was specified."
    }

    $securePassword = Read-Host "Enter a LOCAL emergency password for user '$Name' (SSH can still be key-only)" -AsSecureString
    $resolvedFullName = if ([string]::IsNullOrWhiteSpace($FullName)) { $Name } else { $FullName }

    New-LocalUser -Name $Name -Password $securePassword -FullName $resolvedFullName -Description $Description -AccountNeverExpires | Out-Null
    return Get-LocalUser -Name $Name
}

function Ensure-LocalAdminMembership {
    param([string]$Name)

    $adminsSid = 'S-1-5-32-544'
    $adminsSidObj = New-Object System.Security.Principal.SecurityIdentifier($adminsSid)
    $members = @(Get-LocalGroupMember -SID $adminsSidObj -ErrorAction SilentlyContinue | ForEach-Object { $_.Name.ToLowerInvariant() })
    $candidateNames = @(
        "$env:COMPUTERNAME\$Name".ToLowerInvariant(),
        $Name.ToLowerInvariant()
    )

    $isMember = $false
    foreach ($candidate in $candidateNames) {
        if ($members -contains $candidate) {
            $isMember = $true
            break
        }
    }

    if (-not $isMember) {
        Add-LocalGroupMember -SID $adminsSidObj -Member $Name
    }
}

function Ensure-AuthorizedKey {
    param(
        [string]$Path,
        [string]$Key
    )

    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType File -Path $Path -Force | Out-Null
    }

    $existing = @(Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue)
    if ($existing -notcontains $Key) {
        Add-Content -LiteralPath $Path -Value $Key -Encoding Ascii
    }

    & icacls.exe $Path /inheritance:r /grant '*S-1-5-32-544:F' /grant 'SYSTEM:F' | Out-Null
}

function Backup-FileTimestamped {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $destination = "$Path.$timestamp.bak"
    Copy-Item -LiteralPath $Path -Destination $destination -Force
    return $destination
}

function Ensure-FirewallRule {
    $ruleName = 'OpenSSH-Server-In-TCP'
    $existing = Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-NetFirewallRule -Name $ruleName -DisplayName 'OpenSSH Server (TCP-In)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
    }
}

if (-not (Test-IsAdministrator)) {
    throw 'Run this script from an elevated PowerShell session (Run as Administrator).'
}

$sshdService = Get-Service -Name 'sshd' -ErrorAction SilentlyContinue
if (-not $sshdService) {
    throw 'OpenSSH Server (service sshd) is not installed on this machine.'
}

$sshdExe = "$env:WINDIR\System32\OpenSSH\sshd.exe"
if (-not (Test-Path -LiteralPath $sshdExe)) {
    $cmd = Get-Command sshd.exe -ErrorAction SilentlyContinue
    if ($cmd) {
        $sshdExe = $cmd.Source
    }
    else {
        throw 'sshd.exe not found.'
    }
}

$resolvedPublicKey = Get-ValidatedPublicKey -InlineKey $PublicKey -Path $PublicKeyPath -ParameterSetName $PSCmdlet.ParameterSetName
$resolvedFullName = if ([string]::IsNullOrWhiteSpace($FullName)) { $Username } else { $FullName }
$sshdConfig = 'C:\ProgramData\ssh\sshd_config'
$adminKeys = 'C:\ProgramData\ssh\administrators_authorized_keys'

$user = Ensure-UserExists -Name $Username -FullName $resolvedFullName -Description $Description -SkipCreation:$SkipUserCreation
Ensure-LocalAdminMembership -Name $Username
Ensure-AuthorizedKey -Path $adminKeys -Key $resolvedPublicKey

if ($OpenFirewall) {
    Ensure-FirewallRule
}

$configBackup = Backup-FileTimestamped -Path $sshdConfig
$configLines = Get-ConfigLines -Path $sshdConfig

Set-GlobalDirective -Lines $configLines -Name 'PubkeyAuthentication' -Value 'yes'
Set-GlobalDirective -Lines $configLines -Name 'PermitEmptyPasswords' -Value 'no'

if ($DisablePasswordAuthentication) {
    Set-GlobalDirective -Lines $configLines -Name 'PasswordAuthentication' -Value 'no'
}
else {
    Set-GlobalDirective -Lines $configLines -Name 'PasswordAuthentication' -Value 'yes'
}

if ($RestrictSshToUser) {
    if (-not $Force) {
        Write-Warning "SSH access will be restricted to user '$Username' via AllowUsers."
    }
    Set-GlobalDirective -Lines $configLines -Name 'AllowUsers' -Value $Username
}

Ensure-MatchGroupAdministratorsAuthorizedKeys -Lines $configLines
Save-ConfigLines -Path $sshdConfig -Lines $configLines

& $sshdExe -t
if ($LASTEXITCODE -ne 0) {
    if ($configBackup) {
        Copy-Item -LiteralPath $configBackup -Destination $sshdConfig -Force
    }
    throw 'sshd config validation failed. The previous config backup was restored.'
}

Restart-Service -Name 'sshd'

$adminsSidObj = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
$adminsGroup = Get-LocalGroup -SID $adminsSidObj

Write-Host ''
Write-Host 'Completed.' -ForegroundColor Green
Write-Host "User: $Username"
Write-Host "Full name: $resolvedFullName"
Write-Host 'Authentication: public key enabled'
Write-Host "PasswordAuthentication: $(if ($DisablePasswordAuthentication) { 'disabled' } else { 'enabled' })"
Write-Host "AllowUsers restricted to this user: $(if ($RestrictSshToUser) { 'yes' } else { 'no' })"
Write-Host "Authorized keys file: $adminKeys"
Write-Host "Administrators group resolved as: $($adminsGroup.Name) [S-1-5-32-544]"
if ($configBackup) { Write-Host "Config backup: $configBackup" }
if ($OpenFirewall) { Write-Host 'Firewall: OpenSSH inbound rule ensured on TCP 22' }
Write-Host ''
Write-Host 'Client test:' -ForegroundColor Cyan
Write-Host "  ssh $Username@<server-ip>"
Write-Host ''
Write-Host 'Useful checks on the server:' -ForegroundColor Cyan
Write-Host "  Get-LocalGroupMember -SID (New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544'))"
Write-Host '  Get-WinEvent -LogName "OpenSSH/Operational" -MaxEvents 20 | Select TimeCreated, Id, Message'
