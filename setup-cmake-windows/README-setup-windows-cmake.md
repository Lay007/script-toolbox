# Windows CMake setup kit

Toolkit for installing **CMake** via `winget`.

## Files

- `setup-windows-cmake.ps1` — PowerShell installer for CMake

## What the script does

- checks for elevated PowerShell
- checks that `winget` exists
- checks that the package is available in the `winget` source
- installs CMake
- locates `cmake.exe`
- runs `cmake --version` to verify the installation
- temporarily adds the CMake bin directory to the current session PATH if needed

## Quick start

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\setup-windows-cmake.ps1
```

## Useful parameters

### Reinstall

```powershell
.\setup-windows-cmake.ps1 -ForceReinstall
```

### Show `winget search` output

```powershell
.\setup-windows-cmake.ps1 -PassThruWingetLogs
```

## After installation

1. Open a new terminal.
2. Run:

```powershell
cmake --version
```

3. For MSVC builds, first open a Visual Studio Native Tools prompt or initialize the MSVC environment.

## Notes

- The script defaults to package ID `Kitware.CMake`.
- If the package ID changes, the script will suggest running `winget search cmake`.
