# setup-windows-git-basic.ps1

PowerShell-скрипт для **установки Git for Windows** и **базовой настройки Git** для указанного пользователя Windows.

Скрипт рассчитан на запуск **на сервере Windows из-под администратора**.  
Он:

- устанавливает Git через `winget` или локальный инсталлятор;
- настраивает Git для выбранного пользователя через отдельный `.gitconfig`;
- принимает **SSH private key как параметр**;
- кладёт ключ в `%USERPROFILE%\.ssh\id_ed25519`;
- при возможности автоматически создаёт публичный ключ `id_ed25519.pub`;
- ограничивает ACL для `.ssh`, ключей, `known_hosts` и `.gitconfig`;
- задаёт базовые параметры Git.

## Что настраивается

По умолчанию скрипт выставляет:

- `user.name`
- `user.email`
- `init.defaultBranch=main`
- `fetch.prune=true`
- `pull.rebase=true` или `false` — зависит от параметра
- `push.default=simple`
- `rebase.autoStash=true`
- `core.autocrlf=false` — по умолчанию
- `core.sshCommand=ssh -i "<path-to-key>" -o IdentitiesOnly=yes`
- `credential.helper=manager-core` — если не отключено параметром

## Обязательные параметры

- `-Username`
- `-GitUserName`
- `-GitUserEmail`
- один из двух:
  - `-SshPrivateKeyPath`
  - `-SshPrivateKey`

## Необязательные параметры

- `-SshPublicKeyPath`
- `-SshPublicKey`
- `-InstallMode auto|winget|local|skip`
- `-LocalInstallerPath`
- `-GitPackageId` (по умолчанию `Git.Git`)
- `-DefaultBranch` (по умолчанию `main`)
- `-PullMode rebase|merge` (по умолчанию `rebase`)
- `-AutoCrlf false|true|input` (по умолчанию `false`)
- `-EnableCredentialManager`
- `-InstallGitLfs`

## Примеры запуска

### 1. Установка Git через winget и настройка по private key файлу

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\setup-windows-git-basic.ps1 `
  -Username user-git `
  -GitUserName "Alexander" `
  -GitUserEmail "alex@example.com" `
  -SshPrivateKeyPath C:\user-git\id_ed25519 `
  -InstallMode auto
```

### 2. То же, но с явной передачей public key

```powershell
.\setup-windows-git-basic.ps1 `
  -Username user-git `
  -GitUserName "Alexander" `
  -GitUserEmail "alex@example.com" `
  -SshPrivateKeyPath C:\user-git\id_ed25519 `
  -SshPublicKeyPath C:\user-git\id_ed25519.pub `
  -InstallMode auto
```

### 3. Передача private key строкой

```powershell
$priv = Get-Content C:\user-git\id_ed25519 -Raw
.\setup-windows-git-basic.ps1 `
  -Username user-git `
  -GitUserName "Alexander" `
  -GitUserEmail "alex@example.com" `
  -SshPrivateKey $priv
```

### 4. Установка из локального инсталлятора Git for Windows

```powershell
.\setup-windows-git-basic.ps1 `
  -Username user-git `
  -GitUserName "Alexander" `
  -GitUserEmail "alex@example.com" `
  -SshPrivateKeyPath C:\user-git\id_ed25519 `
  -InstallMode local `
  -LocalInstallerPath C:\Install\Git-64-bit.exe
```

## Что важно знать

### 1. Скрипт ожидает существующего пользователя Windows

Скрипт не создаёт пользователя. Пользователь должен уже существовать.  
Лучше, если он хотя бы один раз входил в систему, чтобы профиль уже был создан.

### 2. Ключ — это именно private key

Параметр `-SshPrivateKeyPath` / `-SshPrivateKey` — это **закрытый SSH-ключ**, который будет использоваться Git при работе по SSH.

### 3. Если ключ защищён passphrase

Скрипт всё равно сможет сохранить ключ, но автоматическая генерация `.pub` из него может не сработать без интерактивного ввода passphrase.

### 4. known_hosts не заполняется автоматически

Скрипт создаёт пустой `known_hosts`, но не добавляет отпечатки удалённых Git-серверов.  
Первое подключение по SSH может спросить подтверждение host key.

## Что проверить после запуска

```powershell
git --version
git config --file "C:\Users\user-git\.gitconfig" --list
type C:\Users\user-git\.ssh\id_ed25519.pub
```

Проверка SSH:

```powershell
ssh -T git@github.com
ssh -T git@gitlab.com
```

## Где лежат результаты

Обычно:

- Git: `C:\Program Files\Git\`
- Git config пользователя: `C:\Users\<Username>\.gitconfig`
- SSH-ключи: `C:\Users\<Username>\.ssh\`

## Типовой сценарий использования

1. Создать или подготовить пользователя Windows.
2. Запустить этот скрипт от администратора.
3. Добавить публичный ключ на GitHub / GitLab / другой Git-сервер.
4. Проверить `ssh -T`.
5. Использовать Git из VS Code Remote SSH.

## Замечание

Если на сервере `winget` работает нестабильно, используйте режим:

```powershell
-InstallMode local -LocalInstallerPath C:\Path\To\Git-Installer.exe
```
