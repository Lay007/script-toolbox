# setup-windows-git-basic.ps1

PowerShell script to **install Git for Windows** and apply **basic Git configuration** for a specified Windows user.

The script is designed to run **on a Windows server from an elevated PowerShell session**.  
It:

- installs Git via `winget` or a local installer;
- configures Git for the selected user using a dedicated `.gitconfig`;
- accepts an **SSH private key as a parameter**;
- writes the key to `%USERPROFILE%\.ssh\id_ed25519`;
- generates `id_ed25519.pub` automatically when possible;
- applies restricted ACLs to `.ssh`, keys, `known_hosts`, and `.gitconfig`;
- sets a practical baseline Git configuration.

## What it configures

By default, the script sets:

- `user.name`
- `user.email`
- `init.defaultBranch=main`
- `fetch.prune=true`
- `pull.rebase=true` or `false` depending on parameters
- `push.default=simple`
- `rebase.autoStash=true`
- `core.autocrlf=false` by default
- `core.sshCommand=ssh -i "<path-to-key>" -o IdentitiesOnly=yes`
- `credential.helper=manager-core` unless disabled

## Required parameters

- `-Username`
- `-GitUserName`
- `-GitUserEmail`
- one of:
  - `-SshPrivateKeyPath`
  - `-SshPrivateKey`

## Optional parameters

- `-SshPublicKeyPath`
- `-SshPublicKey`
- `-InstallMode auto|winget|local|skip`
- `-LocalInstallerPath`
- `-GitPackageId` (default: `Git.Git`)
- `-DefaultBranch` (default: `main`)
- `-PullMode rebase|merge` (default: `rebase`)
- `-AutoCrlf false|true|input` (default: `false`)
- `-EnableCredentialManager`
- `-InstallGitLfs`

## Usage examples

### 1. Install Git via winget and configure from a private key file

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\setup-windows-git-basic.ps1 `
  -Username user-git `
  -GitUserName "Alexander" `
  -GitUserEmail "alex@example.com" `
  -SshPrivateKeyPath C:\user-git\id_ed25519 `
  -InstallMode auto
```

### 2. Same, but with an explicit public key

```powershell
.\setup-windows-git-basic.ps1 `
  -Username user-git `
  -GitUserName "Alexander" `
  -GitUserEmail "alex@example.com" `
  -SshPrivateKeyPath C:\user-git\id_ed25519 `
  -SshPublicKeyPath C:\user-git\id_ed25519.pub `
  -InstallMode auto
```

### 3. Pass the private key as a string

```powershell
$priv = Get-Content C:\user-git\id_ed25519 -Raw
.\setup-windows-git-basic.ps1 `
  -Username user-git `
  -GitUserName "Alexander" `
  -GitUserEmail "alex@example.com" `
  -SshPrivateKey $priv
```

### 4. Install from a local Git for Windows installer

```powershell
.\setup-windows-git-basic.ps1 `
  -Username user-git `
  -GitUserName "Alexander" `
  -GitUserEmail "alex@example.com" `
  -SshPrivateKeyPath C:\user-git\id_ed25519 `
  -InstallMode local `
  -LocalInstallerPath C:\Install\Git-64-bit.exe
```

## Important notes

### 1. The Windows user must already exist

This script does not create the Windows user account.  
The account should already exist, and ideally should have logged in at least once so the profile path exists.

### 2. The key parameter is the private key

`-SshPrivateKeyPath` / `-SshPrivateKey` refers to the **private SSH key** used by Git for SSH authentication.

### 3. If the private key has a passphrase

The script can still place the key, but automatic `.pub` generation may fail without interactive passphrase entry.

### 4. known_hosts is created but not populated

The script creates an empty `known_hosts` file, but does not pre-load remote host fingerprints.  
The first SSH connection may prompt to trust the server key.

## Post-run checks

```powershell
git --version
git config --file "C:\Users\user-git\.gitconfig" --list
type C:\Users\user-git\.ssh\id_ed25519.pub
```

SSH checks:

```powershell
ssh -T git@github.com
ssh -T git@gitlab.com
```

## Output locations

Typically:

- Git: `C:\Program Files\Git\`
- User Git config: `C:\Users\<Username>\.gitconfig`
- SSH keys: `C:\Users\<Username>\.ssh\`

## Typical workflow

1. Prepare the Windows user account.
2. Run this script as Administrator.
3. Add the public key to GitHub / GitLab / another Git host.
4. Verify with `ssh -T`.
5. Use Git from VS Code Remote SSH.

## Tip

If `winget` is unreliable on the server, use:

```powershell
-InstallMode local -LocalInstallerPath C:\Path\To\Git-Installer.exe
```
