# setup-windows-vs2026-buildtools.ps1

PowerShell script for automated installation of **Visual Studio 2026 Build Tools** on Windows.

This version intentionally **does not use** `aka.ms/vs/18/release/vs_buildtools.exe` for bootstrapper download, because in some environments that short URL may return an unexpected HTML page instead of the real `vs_buildtools.exe`.

Instead, the script:

1. downloads the **Visual Studio 2026 Release History** page;
2. extracts a **direct** `download.visualstudio.microsoft.com/.../vs_BuildTools.exe` URL;
3. downloads the bootstrapper from that direct URL;
4. validates that the file is not HTML and appears to be a valid bootstrapper;
5. runs Build Tools installation with the `Microsoft.VisualStudio.Workload.NativeDesktop` workload.

## Default installation target

By default the script installs:

- Visual Studio 2026 Build Tools
- C++ workload: `Microsoft.VisualStudio.Workload.NativeDesktop`

Optionally, you can:
- include recommended components;
- add extra workloads;
- provide a custom `--installPath`;
- download the bootstrapper without launching installation.

## Requirements

- Windows
- Administrator privileges
- PowerShell 5.1+ or PowerShell 7+
- access to `learn.microsoft.com`
- access to `download.visualstudio.microsoft.com`

Recommended:
- `curl.exe` or `Invoke-WebRequest`
- `Start-BitsTransfer` as an extra fallback

## Quick start

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\setup-windows-vs2026-buildtools.ps1 -IncludeRecommended
```

## Examples

### Install with recommended components

```powershell
.\setup-windows-vs2026-buildtools.ps1 -IncludeRecommended
```

### Install to a custom path

```powershell
.\setup-windows-vs2026-buildtools.ps1 `
  -IncludeRecommended `
  -InstallPath "C:\VS\BuildTools2026"
```

### Add extra workloads

```powershell
.\setup-windows-vs2026-buildtools.ps1 `
  -IncludeRecommended `
  -AdditionalWorkloads @(
    "Microsoft.VisualStudio.Workload.VCTools"
  )
```

### Download bootstrapper only

```powershell
.\setup-windows-vs2026-buildtools.ps1 `
  -DownloadOnly `
  -KeepBootstrapper
```

### Keep bootstrapper after installation

```powershell
.\setup-windows-vs2026-buildtools.ps1 `
  -IncludeRecommended `
  -KeepBootstrapper
```

## Parameters

- `-ReleaseHistoryUrl`  
  Release History page URL. Default:
  `https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-history`

- `-BootstrapperOutputDir`  
  Temporary download directory.

- `-BootstrapperFileName`  
  Bootstrapper file name. Default: `vs_BuildTools.exe`.

- `-InstallPath`  
  Custom installation path.

- `-AdditionalWorkloads`  
  Additional Visual Studio workload IDs.

- `-IncludeRecommended`  
  Adds `--includeRecommended`.

- `-KeepBootstrapper`  
  Keep the downloaded bootstrapper after completion.

- `-SkipSignatureCheck`  
  Skip Authenticode signature validation.

- `-DownloadOnly`  
  Download only, do not launch installation.

## Download strategy

The script tries the following download methods:
1. `Invoke-WebRequest`
2. `Start-BitsTransfer`
3. `curl.exe`

After each attempt it validates:
- file size;
- file content is not HTML;
- Microsoft Authenticode signature is valid.

## How to verify installation

### Using vswhere

```powershell
& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" `
  -products * `
  -requires Microsoft.VisualStudio.Workload.NativeDesktop `
  -format json
```

### Using a developer command prompt style check

```powershell
cmd /c where cl
cmd /c where msbuild
```

## If HTML is still downloaded

If the `.exe` file contains HTML instead of a real executable, then your environment is likely rewriting or filtering the request. Check:

```powershell
curl.exe -I -L https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-history
curl.exe -I -L https://download.visualstudio.microsoft.com/
```

## Notes

- The script is designed for **automatic download and installation**.
- It does not depend on `aka.ms` short URLs.
- It uses `vswhere` for post-install verification when available.
