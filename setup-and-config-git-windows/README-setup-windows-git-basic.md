# setup-windows-git-basic.ps1

PowerShell script for **installing Git for Windows** and **basic Git + SSH setup** for a selected Windows user.

The script is designed to run **on a Windows server from an elevated PowerShell session**.
It:

- installs Git via `winget` or a local installer;
- configures Git in a dedicated user `.gitconfig`;
- accepts the **SSH private key as a parameter**;
- copies the private key to `%USERPROFILE%\.ssh\id_ed25519`;
- auto-generates `id_ed25519.pub` when possible;
- creates or updates `%USERPROFILE%\.ssh\config`;
- **asks for the Git server host name at runtime** if `-GitServerHost` is not provided;
- writes a managed `Host` block for the target Git server;
- removes an old `core.sshCommand` from the user `.gitconfig`, so Git uses the standard user OpenSSH config;
- locks down ACLs for `.ssh`, keys, `config`, `known_hosts`, and `.gitconfig`.

## What is configured

By default the script sets:

- `user.name`
- `user.email`
- `init.defaultBranch=main`
- `fetch.prune=true`
- `pull.rebase=true` or `false`
- `push.default=simple`
- `rebase.autoStash=true`
- `core.autocrlf=false`
- `credential.helper=manager-core` unless disabled

It also creates a managed block in `%USERPROFILE%\.ssh\config`, for example:

```sshconfig
Host gitlab.example.com
    HostName gitlab.example.com
    User git
    Port 22
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    PreferredAuthentications publickey
```

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
- `-GitServerHost`
  - if omitted, the script asks for it interactively
- `-GitServerSshUser` (default: `git`)
- `-GitHostAlias`
  - if omitted, it defaults to `GitServerHost`
- `-GitServerPort` (default: `22`)
- `-InstallMode auto|winget|local|skip`
- `-LocalInstallerPath`
- `-GitPackageId` (default: `Git.Git`)
- `-DefaultBranch` (default: `main`)
- `-PullMode rebase|merge` (default: `rebase`)
- `-AutoCrlf false|true|input` (default: `false`)
- `-EnableCredentialManager`
- `-InstallGitLfs`
- `-Force`
  - allows overwriting existing `id_ed25519` / `id_ed25519.pub` when contents differ

## Examples

### 1. Standard run with interactive Git server prompt

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\setup-windows-git-basic.ps1 `
  -Username user-git `
  -GitUserName "Alexander" `
  -GitUserEmail "alex@example.com" `
  -SshPrivateKeyPath C:\user-git\id_ed25519 `
  -InstallMode auto
```

### 2. Provide the Git server explicitly

```powershell
.\setup-windows-git-basic.ps1 `
  -Username user-git `
  -GitUserName "Alexander" `
  -GitUserEmail "alex@example.com" `
  -SshPrivateKeyPath C:\user-git\id_ed25519 `
  -GitServerHost github.com `
  -GitServerSshUser git
```

### 3. Use a custom SSH alias

```powershell
.\setup-windows-git-basic.ps1 `
  -Username user-git `
  -GitUserName "Alexander" `
  -GitUserEmail "alex@example.com" `
  -SshPrivateKeyPath C:\user-git\id_ed25519 `
  -GitServerHost github.com `
  -GitHostAlias my-git
```

### 4. Pass the private key as a string

```powershell
$priv = Get-Content C:\user-git\id_ed25519 -Raw
.\setup-windows-git-basic.ps1 `
  -Username user-git `
  -GitUserName "Alexander" `
  -GitUserEmail "alex@example.com" `
  -SshPrivateKey $priv
```

## Post-run checks

```powershell
git --version
git config --file "C:\Users\user-git\.gitconfig" --list
type C:\Users\user-git\.ssh\config
type C:\Users\user-git\.ssh\id_ed25519.pub
```

SSH connectivity check:

```powershell
ssh -F "C:\Users\user-git\.ssh\config" -T github.com
```

## Notes

### 1. The script does not create the Windows user

The target Windows user must already exist.
It is better if the user has logged in at least once so the profile already exists.

### 2. The key parameter is the private key

`-SshPrivateKeyPath` / `-SshPrivateKey` is the **private SSH key** used by Git over SSH.

### 3. Passphrase-protected keys

The script can still save the key, but automatic public-key generation may fail without interactive passphrase entry.

### 4. `known_hosts` is not populated automatically

The script creates an empty `known_hosts`, but does not pre-load server fingerprints.
The first SSH connection may ask you to confirm the server host key.

### 5. Managed block in `.ssh\config`

The script does not overwrite the whole SSH config.
It only creates or updates a marked block:

```text
# BEGIN managed by setup-windows-git-basic.ps1 : <alias>
...
# END managed by setup-windows-git-basic.ps1 : <alias>
```
