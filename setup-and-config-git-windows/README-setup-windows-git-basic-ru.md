# setup-windows-git-basic.ps1

PowerShell-скрипт для **установки Git for Windows** и **базовой настройки Git + SSH** для указанного пользователя Windows.

Скрипт рассчитан на запуск **на сервере Windows из-под администратора**.
Он:

- устанавливает Git через `winget` или локальный инсталлятор;
- настраивает Git для выбранного пользователя через отдельный `.gitconfig`;
- принимает **SSH private key как параметр**;
- копирует закрытый ключ в `%USERPROFILE%\.ssh\id_ed25519`;
- при возможности автоматически создаёт публичный ключ `id_ed25519.pub`;
- создаёт или обновляет `%USERPROFILE%\.ssh\config`;
- при запуске **спрашивает имя Git-сервера**, если параметр `-GitServerHost` не передан;
- создаёт отдельный `Host`-блок для нужного Git-сервера;
- удаляет из пользовательского `.gitconfig` старый `core.sshCommand`, чтобы Git использовал обычный OpenSSH-конфиг пользователя;
- ограничивает ACL для `.ssh`, ключей, `config`, `known_hosts` и `.gitconfig`.

## Что именно настраивается

По умолчанию скрипт выставляет:

- `user.name`
- `user.email`
- `init.defaultBranch=main`
- `fetch.prune=true`
- `pull.rebase=true` или `false` — зависит от параметра
- `push.default=simple`
- `rebase.autoStash=true`
- `core.autocrlf=false` — по умолчанию
- `credential.helper=manager-core` — если не отключено параметром

В `%USERPROFILE%\.ssh\config` создаётся managed-блок вида:

```sshconfig
Host github.com
    HostName github.com
    User git
    Port 22
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    PreferredAuthentications publickey
```

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
- `-GitServerHost`
  - если не передать, скрипт спросит его интерактивно
- `-GitServerSshUser` (по умолчанию `git`)
- `-GitHostAlias`
  - если не передать, будет равен `GitServerHost`
- `-GitServerPort` (по умолчанию `22`)
- `-InstallMode auto|winget|local|skip`
- `-LocalInstallerPath`
- `-GitPackageId` (по умолчанию `Git.Git`)
- `-DefaultBranch` (по умолчанию `main`)
- `-PullMode rebase|merge` (по умолчанию `rebase`)
- `-AutoCrlf false|true|input` (по умолчанию `false`)
- `-EnableCredentialManager`
- `-InstallGitLfs`
- `-Force`
  - разрешает перезаписать уже существующие `id_ed25519` / `id_ed25519.pub`, если их содержимое отличается

## Примеры запуска

### 1. Обычный запуск с интерактивным вводом имени Git-сервера

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\setup-windows-git-basic.ps1 `
  -Username user-git `
  -GitUserName "Alexander" `
  -GitUserEmail "alex@example.com" `
  -SshPrivateKeyPath C:\user-git\id_ed25519 `
  -InstallMode auto
```

Скрипт сам спросит, например:

```text
Enter Git server hostname (for example: gitlab.example.com): github.com
Enter Git SSH username [git]:
```

### 2. С явной передачей Git-сервера

```powershell
.\setup-windows-git-basic.ps1 `
  -Username user-git `
  -GitUserName "Alexander" `
  -GitUserEmail "alex@example.com" `
  -SshPrivateKeyPath C:\user-git\id_ed25519 `
  -GitServerHost github.com `
  -GitServerSshUser git `
  -InstallMode auto
```

### 3. Если нужен отдельный alias в SSH config

```powershell
.\setup-windows-git-basic.ps1 `
  -Username user-git `
  -GitUserName "Alexander" `
  -GitUserEmail "alex@example.com" `
  -SshPrivateKeyPath C:\user-git\id_ed25519 `
  -GitServerHost github.com `
  -GitHostAlias my-git
```

Тогда в `.ssh\config` получится блок:

```sshconfig
Host my-git github.com
    HostName github.com
    User git
    Port 22
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    PreferredAuthentications publickey
```

И можно использовать URL с alias, если захочется.

### 4. Передача private key строкой

```powershell
$priv = Get-Content C:\user-git\id_ed25519 -Raw
.\setup-windows-git-basic.ps1 `
  -Username user-git `
  -GitUserName "Alexander" `
  -GitUserEmail "alex@example.com" `
  -SshPrivateKey $priv
```

### 5. Принудительная перезапись ключей

```powershell
.\setup-windows-git-basic.ps1 `
  -Username user-git `
  -GitUserName "Alexander" `
  -GitUserEmail "alex@example.com" `
  -SshPrivateKeyPath C:\user-git\id_ed25519 `
  -Force
```

## Что проверить после запуска

```powershell
git --version
git config --file "C:\Users\user-git\.gitconfig" --list
type C:\Users\user-git\.ssh\config
type C:\Users\user-git\.ssh\id_ed25519.pub
```

Проверка SSH:

```powershell
ssh -F "C:\Users\user-git\.ssh\config" -T github.com
```

или, если использован alias:

```powershell
ssh -F "C:\Users\user-git\.ssh\config" -T my-git
```

## Важные замечания

### 1. Скрипт не создаёт пользователя Windows

Пользователь Windows должен уже существовать.
Лучше, если он хотя бы один раз входил в систему, чтобы профиль уже был создан.

### 2. Ключ — это именно private key

Параметр `-SshPrivateKeyPath` / `-SshPrivateKey` — это **закрытый SSH-ключ**, который будет использоваться Git при работе по SSH.

### 3. Если ключ защищён passphrase

Скрипт всё равно сможет сохранить ключ, но автоматическая генерация `.pub` из него может не сработать без интерактивного ввода passphrase.

### 4. known_hosts не заполняется автоматически

Скрипт создаёт пустой `known_hosts`, но не добавляет отпечатки удалённых Git-серверов.
Первое подключение по SSH может спросить подтверждение host key.

### 5. Managed-блок в `.ssh\config`

Скрипт не затирает весь пользовательский `config`.
Он создаёт или обновляет только свой помеченный блок:

```text
# BEGIN managed by setup-windows-git-basic.ps1 : <alias>
...
# END managed by setup-windows-git-basic.ps1 : <alias>
```

Это удобно, если у пользователя уже есть другие SSH-хосты.

## Где лежат результаты

Обычно:

- Git: `C:\Program Files\Git\`
- Git config пользователя: `C:\Users\<Username>\.gitconfig`
- SSH-ключи: `C:\Users\<Username>\.ssh\`
- SSH config: `C:\Users\<Username>\.ssh\config`

## Типовой сценарий использования

1. Подготовить пользователя Windows.
2. Запустить этот скрипт от администратора.
3. Передать имя Git-сервера при запуске.
4. Добавить публичный ключ на GitLab / GitHub / другой Git-сервер.
5. Проверить `ssh -T`.
6. Использовать Git из VS Code Remote SSH.
