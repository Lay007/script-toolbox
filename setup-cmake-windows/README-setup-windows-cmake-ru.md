# Windows CMake setup kit

Набор для установки **CMake** через `winget`.

## Файлы

- `setup-windows-cmake.ps1` — PowerShell-скрипт установки CMake

## Что делает скрипт

- проверяет, что PowerShell запущен от администратора
- проверяет наличие `winget`
- проверяет доступность пакета в источнике `winget`
- ставит CMake
- находит `cmake.exe`
- запускает `cmake --version` для проверки
- если нужно, временно добавляет путь к CMake в `PATH` только для текущей сессии

## Быстрый запуск

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\setup-windows-cmake.ps1
```

## Полезные параметры

### Переустановка

```powershell
.\setup-windows-cmake.ps1 -ForceReinstall
```

### Показать вывод `winget search`

```powershell
.\setup-windows-cmake.ps1 -PassThruWingetLogs
```

## Что делать после установки

1. Открой новый терминал.
2. Выполни:

```powershell
cmake --version
```

3. Для сборки через MSVC сначала открой Visual Studio Native Tools prompt или инициализируй окружение MSVC.

## Примечания

- Скрипт по умолчанию использует package ID `Kitware.CMake`.
- Если package ID изменится, скрипт подскажет выполнить `winget search cmake`.
