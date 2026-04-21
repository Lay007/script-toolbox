# Windows OpenSSH key-only setup kit

This package contains:

- `setup-windows-openssh-keyonly.ps1` — the main PowerShell script
- `README-setup-windows-openssh-keyonly.md` — this guide
- `README-setup-windows-openssh-keyonly-ru.md` — Russian guide

## What changed in this version

This version requires that **both the user name and the key are always passed explicitly as parameters**.

You must now provide:

- `-Username <user_name>`
- and one key option:
  - `-PublicKeyPath <path_to_pubkey_file>`
  - `-PublicKey <public_key_string>`

There is no default username anymore.

## What the script does

The script prepares a Windows machine for SSH access with a local administrator account and public-key authentication.

It:

- verifies that PowerShell is running elevated
- checks that the `sshd` service exists
- creates the local user if needed
- adds the user to the built-in Administrators group using SID `S-1-5-32-544`
- adds the public key to `C:\ProgramData\ssh\administrators_authorized_keys`
- applies the required ACLs to that file
- updates `C:\ProgramData\ssh\sshd_config`
- validates the config with `sshd -t`
- restarts the `sshd` service

## Required parameters

You must provide:

- `-Username <name>`
- and exactly one key option:
  - `-PublicKeyPath <path>`
  - `-PublicKey <string>`

## Optional parameters

- `-FullName <name>` — full name for the account; defaults to `Username`
- `-Description <text>` — account description
- `-DisablePasswordAuthentication <bool>` — disables SSH password login; default `True`
- `-RestrictSshToUser <bool>` — adds `AllowUsers <Username>`; default `True`
- `-OpenFirewall` — ensures the inbound firewall rule for TCP 22
- `-SkipUserCreation` — fails if the user does not already exist
- `-Force` — suppresses the warning about `AllowUsers`

## Examples

### Basic usage

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\setup-windows-openssh-keyonly.ps1 -Username user-ssh -PublicKeyPath C:\key-user-ssh.pub
```

### With firewall rule

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\setup-windows-openssh-keyonly.ps1 `
  -Username user-ssh `
  -PublicKeyPath C:\key-user-ssh.pub `
  -OpenFirewall `
  -Force
```

### Pass the public key inline

```powershell
$pub = Get-Content C:\key-user-ssh.pub -Raw
.\setup-windows-openssh-keyonly.ps1 -Username user-ssh -PublicKey $pub
```

## sshd_config changes

The script ensures these global directives are present:

```text
PubkeyAuthentication yes
PermitEmptyPasswords no
PasswordAuthentication no
AllowUsers user-ssh
```

If `-RestrictSshToUser $false` is used, `AllowUsers` is not added.

It also ensures this block exists:

```text
Match Group administrators
    AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
```

## Backup and validation

Before editing the config, the script creates a timestamped backup:

```text
C:\ProgramData\ssh\sshd_config.YYYYMMDD-HHMMSS.bak
```

Then it runs:

```powershell
sshd.exe -t
```

If validation fails, the backup is restored.

## Post-run checks

### From the client

```bash
ssh user-ssh@<server-ip>
```

### On the server

Check that the user is in the local Administrators group:

```powershell
Get-LocalGroupMember -SID (New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544'))
```

Check the OpenSSH log:

```powershell
Get-WinEvent -LogName "OpenSSH/Operational" -MaxEvents 20 |
  Select-Object TimeCreated, Id, Message
```

## Notes

- Keep an RDP session open while testing SSH.
- For admin users on Windows OpenSSH, the public key is stored in `C:\ProgramData\ssh\administrators_authorized_keys`.
- `AllowUsers` can lock out other SSH users.
- If the client shows `REMOTE HOST IDENTIFICATION HAS CHANGED`, verify the server host-key fingerprint and update the client's `known_hosts` entry.

## Reuse examples

### Another user

```powershell
.\setup-windows-openssh-keyonly.ps1 -Username buildbot -PublicKeyPath C:\temp\buildbot.pub
```

### Do not restrict SSH to a single user

```powershell
.\setup-windows-openssh-keyonly.ps1 `
  -Username user-ssh `
  -PublicKeyPath C:\key-user-ssh.pub `
  -RestrictSshToUser $false
```

### Keep SSH password login temporarily

```powershell
.\setup-windows-openssh-keyonly.ps1 `
  -Username user-ssh `
  -PublicKeyPath C:\key-user-ssh.pub `
  -DisablePasswordAuthentication $false
```
