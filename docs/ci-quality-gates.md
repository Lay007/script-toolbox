# CI Quality Gates

This document explains the automated checks used by `script-toolbox`.

The goal is to catch repository hygiene issues without executing setup scripts that modify a machine.

## Quality gate summary

| Gate | Script or tool | What it checks | Executes setup scripts? |
|---|---|---|---|
| PowerShell syntax | `tools/test-powershell-syntax.ps1` | Every `.ps1` file can be parsed by the PowerShell AST parser | No |
| Markdown links | `tools/test-markdown-links.ps1` | Relative links in Markdown files point to existing files or directories | No |
| Static analysis | `PSScriptAnalyzer` with `PSScriptAnalyzerSettings.psd1` | Error-level PowerShell issues and visible warning diagnostics | No |

## Local usage

Run syntax checks:

```powershell
pwsh -NoProfile -File tools/test-powershell-syntax.ps1
```

Run Markdown relative link checks:

```powershell
pwsh -NoProfile -File tools/test-markdown-links.ps1
```

Run PSScriptAnalyzer with repository settings:

```powershell
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force
Invoke-ScriptAnalyzer -Path . -Recurse -Settings PSScriptAnalyzerSettings.psd1
```

## Why the checks avoid execution

Most scripts in this repository are setup or administration scripts. They may change SSH configuration, user accounts, ACLs, PATH variables, installed software or developer tools.

CI therefore focuses on checks that can run safely on GitHub-hosted runners without changing the runner state in a way that pretends to validate a real workstation setup.

## Warning policy

The workflow fails on error-level findings. Warning-level findings remain visible in logs and should be reviewed when changing a script.

The `PSUseApprovedVerbs` rule is excluded because this repository uses idempotent helper names such as `Ensure-*` to make setup intent clear. This exception is documented in `PSScriptAnalyzerSettings.psd1`.
