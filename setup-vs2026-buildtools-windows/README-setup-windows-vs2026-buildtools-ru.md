# setup-windows-vs2026-buildtools.ps1

PowerShell-скрипт для автоматической установки **Visual Studio 2026 Build Tools** на Windows.

Главная идея этого варианта: скрипт **не использует `aka.ms/vs/18/release/vs_buildtools.exe`** для скачивания bootstrapper, потому что в некоторых сетях короткая ссылка может неожиданно возвращать HTML-страницу Bing вместо `vs_buildtools.exe`.

Вместо этого скрипт:

1. скачивает страницу **Visual Studio 2026 Release History**;
2. находит на ней **прямую** ссылку на `download.visualstudio.microsoft.com/.../vs_BuildTools.exe`;
3. скачивает bootstrapper по прямому URL;
4. проверяет, что это не HTML и что файл выглядит валидным;
5. запускает установку Build Tools с workload `Microsoft.VisualStudio.Workload.NativeDesktop`.

## Что устанавливается по умолчанию

- Visual Studio 2026 Build Tools
- C++ workload: `Microsoft.VisualStudio.Workload.NativeDesktop`

Опционально можно:
- включить recommended-компоненты;
- добавить другие workload'ы;
- указать свой `--installPath`;
- скачать bootstrapper без запуска установки.

## Требования

- Windows с правами администратора
- PowerShell 5.1+ или PowerShell 7+
- доступ к `learn.microsoft.com`
- доступ к `download.visualstudio.microsoft.com`

Желательно:
- `curl.exe` или `Invoke-WebRequest`
- `Start-BitsTransfer` как дополнительный fallback

## Быстрый запуск

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\setup-windows-vs2026-buildtools.ps1 -IncludeRecommended
```

## Примеры

### Установка с recommended-компонентами

```powershell
.\setup-windows-vs2026-buildtools.ps1 -IncludeRecommended
```

### Установка в свой каталог

```powershell
.\setup-windows-vs2026-buildtools.ps1 `
  -IncludeRecommended `
  -InstallPath "C:\VS\BuildTools2026"
```

### Добавить дополнительные workload'ы

```powershell
.\setup-windows-vs2026-buildtools.ps1 `
  -IncludeRecommended `
  -AdditionalWorkloads @(
    "Microsoft.VisualStudio.Workload.VCTools"
  )
```

### Только скачать bootstrapper

```powershell
.\setup-windows-vs2026-buildtools.ps1 `
  -DownloadOnly `
  -KeepBootstrapper
```

### Оставить bootstrapper после установки

```powershell
.\setup-windows-vs2026-buildtools.ps1 `
  -IncludeRecommended `
  -KeepBootstrapper
```

## Параметры

- `-ReleaseHistoryUrl`  
  URL страницы Release History. По умолчанию:
  `https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-history`

- `-BootstrapperOutputDir`  
  Каталог для временной загрузки bootstrapper.

- `-BootstrapperFileName`  
  Имя файла bootstrapper. По умолчанию `vs_BuildTools.exe`.

- `-InstallPath`  
  Кастомный путь установки.

- `-AdditionalWorkloads`  
  Дополнительные workload ID для Visual Studio installer.

- `-IncludeRecommended`  
  Добавляет `--includeRecommended`.

- `-KeepBootstrapper`  
  Не удалять скачанный bootstrapper после завершения.

- `-SkipSignatureCheck`  
  Пропустить проверку Authenticode-подписи.

- `-DownloadOnly`  
  Только скачать bootstrapper, не запускать установку.

## Что делает скрипт при скачивании

Скрипт пробует:
1. `Invoke-WebRequest`
2. `Start-BitsTransfer`
3. `curl.exe`

После каждого способа он проверяет:
- размер файла;
- не является ли файл HTML;
- валидна ли цифровая подпись Microsoft.

## Как проверить установку

### Через vswhere

```powershell
& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" `
  -products * `
  -requires Microsoft.VisualStudio.Workload.NativeDesktop `
  -format json
```

### Через командную строку разработчика

Если установлен Visual Studio Build Tools, можно проверить наличие инструментов:

```powershell
cmd /c where cl
cmd /c where msbuild
```

## Если снова скачивается HTML

Если скачанный `.exe` на самом деле содержит HTML, значит:
- прокси или фильтр подменяет ответ;
- `learn.microsoft.com` или `download.visualstudio.microsoft.com` режется на уровне сети;
- на сервере работает корпоративный web-фильтр.

В этом случае проверь:

```powershell
curl.exe -I -L https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-history
curl.exe -I -L https://download.visualstudio.microsoft.com/
```

## Замечания

- Скрипт рассчитан именно на **автоматическое скачивание и установку**.
- Он не зависит от `aka.ms` short URL.
- Для поиска установленной Visual Studio используется `vswhere`, если он есть в системе.
