# script-toolbox

[![PowerShell lint](https://github.com/Lay007/script-toolbox/actions/workflows/powershell-lint.yml/badge.svg)](https://github.com/Lay007/script-toolbox/actions/workflows/powershell-lint.yml)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B%20%7C%207%2B-5391FE?logo=powershell&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Windows-0078D6?logo=windows&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green.svg)

A practical collection of reusable PowerShell scripts for Windows setup, SSH access configuration, Git onboarding, developer tooling installation, and everyday infrastructure tasks.

This repository is intended for developers, administrators, and power users who want repeatable, scriptable, and documented setup routines instead of manual clicking through installers and system settings.

---

## Engineering value

`script-toolbox` turns repeated Windows workstation and remote-access setup into documented, inspectable and repeatable engineering procedures.

| Scenario | Toolkit | Result |
|---|---|---|
| Prepare a Windows host for SSH administration | [`config-ssh-client-windows`](./config-ssh-client-windows) | key-based OpenSSH access with validation and safer permissions |
| Create a clean Git + SSH workflow for a dedicated user | [`setup-and-config-git-windows`](./setup-and-config-git-windows) | reproducible Git identity, SSH key placement and managed SSH config |
| Install CMake on a Windows build machine | [`setup-cmake-windows`](./setup-cmake-windows) | verified CMake installation and current-session PATH recovery |
| Install native C++ build tools | [`setup-vs2026-buildtools-windows`](./setup-vs2026-buildtools-windows) | Visual Studio Build Tools bootstrap with installer validation |

Safety and review rules are documented in [Engineering Safety Model](./docs/engineering-safety-model.md).

---

## CI and quality gates

The repository uses a PowerShell lint workflow with three layers:

1. `tools/test-powershell-syntax.ps1` parses all `.ps1` files through the PowerShell AST parser without executing target scripts.
2. `tools/test-markdown-links.ps1` checks relative Markdown links so README and docs stay synchronized with the repository layout.
3. `PSScriptAnalyzer` runs with repository settings from `PSScriptAnalyzerSettings.psd1`.

See [CI Quality Gates](./docs/ci-quality-gates.md) for local commands and policy details.

The analyzer is configured to fail the workflow on error-level findings while keeping warning-level findings visible in the job log.

---

## What this repository is for

`script-toolbox` is a curated set of focused setup kits that help you:

- configure Windows machines for SSH-based access;
- prepare Git + SSH workflow for a dedicated user;
- install core developer tools in a reproducible way;
- reduce routine environment setup time;
- keep operational knowledge close to the scripts themselves.

The repository is organized as small self-contained toolkits.
Each toolkit usually contains:

- the main PowerShell script;
- an English README;
- a Russian README.

---

## Current contents

### 1. Windows OpenSSH key-only setup

Directory: [`config-ssh-client-windows`](./config-ssh-client-windows)

Use this kit to prepare a Windows machine for SSH access with public-key authentication.

Main script:
- [`setup-windows-openssh-keyonly.ps1`](./config-ssh-client-windows/setup-windows-openssh-keyonly.ps1)

Documentation:
- [English guide](./config-ssh-client-windows/README-setup-windows-openssh-keyonly.md)
- [Russian guide](./config-ssh-client-windows/README-setup-windows-openssh-keyonly-ru.md)

What it does:
- validates elevated PowerShell execution;
- checks OpenSSH server availability;
- creates or prepares a local admin-capable user;
- configures `administrators_authorized_keys`;
- updates `sshd_config`;
- validates configuration and restarts `sshd`.

### 2. Git for Windows + basic Git/SSH setup

Directory: [`setup-and-config-git-windows`](./setup-and-config-git-windows)

Use this kit to install Git for Windows and configure a clean Git + SSH workflow for a target Windows user.

Main script:
- [`setup-windows-git-basic.ps1`](./setup-and-config-git-windows/setup-windows-git-basic.ps1)

Documentation:
- [English guide](./setup-and-config-git-windows/README-setup-windows-git-basic.md)
- [Russian guide](./setup-and-config-git-windows/README-setup-windows-git-basic-ru.md)

What it does:
- installs Git via `winget` or local installer;
- configures user-level `.gitconfig`;
- installs and places SSH keys;
- builds a managed SSH config block;
- sets sane Git defaults;
- tightens ACLs for `.ssh` and related files.

### 3. CMake installation kit for Windows

Directory: [`setup-cmake-windows`](./setup-cmake-windows)

Use this kit to install CMake on Windows in a straightforward and repeatable way.

Main script:
- [`setup-windows-cmake.ps1`](./setup-cmake-windows/setup-windows-cmake.ps1)

Documentation:
- [English guide](./setup-cmake-windows/README-setup-windows-cmake.md)
- [Russian guide](./setup-cmake-windows/README-setup-windows-cmake-ru.md)

What it does:
- checks elevation and `winget`;
- installs CMake from the package source;
- verifies installation with `cmake --version`;
- temporarily fixes PATH in the current session if needed.

### 4. Visual Studio 2026 Build Tools installer

Directory: [`setup-vs2026-buildtools-windows`](./setup-vs2026-buildtools-windows)

Use this kit to automate installation of Visual Studio 2026 Build Tools for native C++ development.

Main script:
- [`setup-windows-vs2026-buildtools.ps1`](./setup-vs2026-buildtools-windows/setup-windows-vs2026-buildtools.ps1)

Documentation:
- [English guide](./setup-vs2026-buildtools-windows/README-setup-windows-vs2026-buildtools.md)
- [Russian guide](./setup-vs2026-buildtools-windows/README-setup-windows-vs2026-buildtools-ru.md)

What it does:
- resolves a direct bootstrapper URL from the official release history page;
- avoids fragile short-link behavior;
- validates the downloaded file;
- installs Native Desktop C++ workload;
- supports recommended components and extra workloads;
- supports download-only mode.

---

## Repository structure

```text
script-toolbox/
├─ config-ssh-client-windows/
│  ├─ README-setup-windows-openssh-keyonly.md
│  ├─ README-setup-windows-openssh-keyonly-ru.md
│  └─ setup-windows-openssh-keyonly.ps1
├─ docs/
│  ├─ ci-quality-gates.md
│  └─ engineering-safety-model.md
├─ setup-and-config-git-windows/
│  ├─ README-setup-windows-git-basic.md
│  ├─ README-setup-windows-git-basic-ru.md
│  └─ setup-windows-git-basic.ps1
├─ setup-cmake-windows/
│  ├─ README-setup-windows-cmake.md
│  ├─ README-setup-windows-cmake-ru.md
│  └─ setup-windows-cmake.ps1
├─ setup-vs2026-buildtools-windows/
│  ├─ README-setup-windows-vs2026-buildtools.md
│  ├─ README-setup-windows-vs2026-buildtools-ru.md
│  └─ setup-windows-vs2026-buildtools.ps1
├─ tools/
│  ├─ test-markdown-links.ps1
│  └─ test-powershell-syntax.ps1
├─ CHANGELOG.md
├─ CONTRIBUTING.md
├─ PSScriptAnalyzerSettings.psd1
├─ SECURITY.md
└─ README.md
```

---

## Quick start

Clone the repository:

```powershell
git clone git@github.com:Lay007/script-toolbox.git
cd script-toolbox
```

Run the desired script from an elevated PowerShell session.

Example: install CMake

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
cd .\setup-cmake-windows
.\setup-windows-cmake.ps1
```

Example: install Visual Studio 2026 Build Tools

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
cd .\setup-vs2026-buildtools-windows
.\setup-windows-vs2026-buildtools.ps1 -IncludeRecommended
```

Example: install Git and configure SSH

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
cd .\setup-and-config-git-windows
.\setup-windows-git-basic.ps1 `
  -Username user-git `
  -GitUserName "Alexander" `
  -GitUserEmail "alex@example.com" `
  -SshPrivateKeyPath C:\user-git\id_ed25519 `
  -GitServerHost github.com
```

---

## Principles

This repository follows a few practical rules:

- **small focused scripts** instead of one oversized monolith;
- **explicit parameters** instead of hidden assumptions;
- **repeatable setup** instead of one-off manual actions;
- **documentation next to code** so usage stays understandable;
- **operational safety first** with validation and post-run checks where possible.

---

## Notes

- Most scripts are intended to be run from **elevated PowerShell**.
- The current repository is focused on **Windows administration and developer environment setup**.
- Read the toolkit-specific README before using a script in production or on a remote system.
- For SSH-related changes, it is a good idea to keep an active RDP or console session available while testing access.

---

## Intended audience

This repository may be useful for:

- C++ developers preparing Windows build environments;
- administrators configuring SSH access on Windows hosts;
- engineers setting up Git-based workflows for local or remote machines;
- anyone who prefers scriptable, inspectable setup over manual repetitive steps.

---

## Roadmap

Planned or natural future additions may include:

- more Windows bootstrap scripts;
- package/install helpers for common developer tools;
- workstation provisioning helpers;
- reusable diagnostics and maintenance scripts;
- better indexing and categorization by use case.

---

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](./CONTRIBUTING.md) and [CHANGELOG.md](./CHANGELOG.md) for repository workflow notes.

When contributing, prefer:

- clear script names;
- predictable parameters;
- safe defaults;
- comments only where they add value;
- documentation updates together with behavior changes.

---

## License

MIT
