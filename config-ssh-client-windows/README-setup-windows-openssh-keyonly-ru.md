# Windows OpenSSH key-only setup kit (RU)

В комплекте:

- `setup-windows-openssh-keyonly.ps1` — основной PowerShell-скрипт
- `README-setup-windows-openssh-keyonly-ru.md` — инструкция на русском
- `README-setup-windows-openssh-keyonly.md` — инструкция на английском

## Что изменено в этой версии

В этой версии **имя пользователя и ключ всегда задаются явно через параметры**.

Теперь обязательно передавать:

- `-Username <имя_пользователя>`
- и один из вариантов ключа:
  - `-PublicKeyPath <путь_к_файлу>`
  - `-PublicKey <строка_публичного_ключа>`

Скрипт больше не использует имя пользователя по умолчанию.

## Что делает скрипт

Скрипт подготавливает Windows-машину для входа по SSH с локальной учётной записью администратора и авторизацией только по публичному ключу.

Он:

- проверяет, что PowerShell запущен от имени администратора
- проверяет наличие службы `sshd`
- при необходимости создаёт локального пользователя
- добавляет пользователя во встроенную локальную группу администраторов через SID `S-1-5-32-544`
- добавляет публичный ключ в `C:\ProgramData\ssh\administrators_authorized_keys`
- выставляет правильные ACL на этот файл
- правит `C:\ProgramData\ssh\sshd_config`
- проверяет конфиг через `sshd -t`
- перезапускает службу `sshd`

## Обязательные параметры

Нужно передать **обязательно**:

- `-Username <имя>`
- и **один** из вариантов ключа:
  - `-PublicKeyPath <путь>`
  - `-PublicKey <строка>`

## Необязательные параметры

- `-FullName <имя>` — полное имя учётной записи; по умолчанию равно `Username`
- `-Description <текст>` — описание учётной записи
- `-DisablePasswordAuthentication <bool>` — отключить парольный вход SSH; по умолчанию `True`
- `-RestrictSshToUser <bool>` — добавить `AllowUsers <Username>`; по умолчанию `True`
- `-OpenFirewall` — создать/проверить входящее правило firewall для TCP 22
- `-SkipUserCreation` — не создавать пользователя, если он отсутствует
- `-Force` — не показывать предупреждение при добавлении `AllowUsers`

## Примеры запуска

### Базовый сценарий

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\setup-windows-openssh-keyonly.ps1 -Username user-ssh -PublicKeyPath C:\key-user-ssh.pub
```

### С открытием firewall-правила

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\setup-windows-openssh-keyonly.ps1 `
  -Username user-ssh `
  -PublicKeyPath C:\key-user-ssh.pub `
  -OpenFirewall `
  -Force
```

### Передать публичный ключ строкой

```powershell
$pub = Get-Content C:\key-user-ssh.pub -Raw
.\setup-windows-openssh-keyonly.ps1 -Username user-ssh -PublicKey $pub
```

## Что меняется в sshd_config

Скрипт обеспечивает наличие глобальных директив:

```text
PubkeyAuthentication yes
PermitEmptyPasswords no
PasswordAuthentication no
AllowUsers user-ssh
```

Если включён `-RestrictSshToUser $false`, директива `AllowUsers` не добавляется.

Также скрипт обеспечивает наличие блока:

```text
Match Group administrators
    AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
```

## Резервная копия и проверка

Перед изменением конфига создаётся резервная копия:

```text
C:\ProgramData\ssh\sshd_config.YYYYMMDD-HHMMSS.bak
```

После этого выполняется проверка:

```powershell
sshd.exe -t
```

Если конфиг невалидный, скрипт восстанавливает резервную копию.

## Проверка после запуска

### С клиентской машины

```bash
ssh user-ssh@<ip_сервера>
```

### На сервере

Проверить, что пользователь состоит в локальных администраторах:

```powershell
Get-LocalGroupMember -SID (New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544'))
```

Посмотреть журнал OpenSSH:

```powershell
Get-WinEvent -LogName "OpenSSH/Operational" -MaxEvents 20 |
  Select-Object TimeCreated, Id, Message
```

## Полезные замечания

- Во время настройки лучше держать открытым RDP-сеанс.
- Для администраторских учётных записей Windows OpenSSH использует `C:\ProgramData\ssh\administrators_authorized_keys`.
- `AllowUsers` может ограничить вход других SSH-пользователей.
- Если на клиенте появилось предупреждение `REMOTE HOST IDENTIFICATION HAS CHANGED`, проверь fingerprint серверного host key и обнови `known_hosts` на клиенте.

## Короткий сценарий повторного использования

### Другой пользователь

```powershell
.\setup-windows-openssh-keyonly.ps1 -Username buildbot -PublicKeyPath C:\temp\buildbot.pub
```

### Не ограничивать SSH только одним пользователем

```powershell
.\setup-windows-openssh-keyonly.ps1 `
  -Username user-ssh `
  -PublicKeyPath C:\key-user-ssh.pub `
  -RestrictSshToUser $false
```

### Временно оставить парольный вход SSH

```powershell
.\setup-windows-openssh-keyonly.ps1 `
  -Username user-ssh `
  -PublicKeyPath C:\key-user-ssh.pub `
  -DisablePasswordAuthentication $false
```
