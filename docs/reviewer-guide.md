# Reviewer Guide

This guide gives a compact path for evaluating `script-toolbox`.

## What to review first

| Step | Page / path | What it proves |
|---:|---|---|
| 1 | [README](../README.md) | Toolkit scope and supported Windows setup scenarios |
| 2 | [Engineering safety model](engineering-safety-model.md) | Safety expectations for setup scripts |
| 3 | [CI quality gates](ci-quality-gates.md) | Syntax, Markdown link and PSScriptAnalyzer checks |
| 4 | `config-ssh-client-windows/` | Key-only OpenSSH setup workflow |
| 5 | `setup-and-config-git-windows/` | Git + SSH onboarding workflow |
| 6 | `setup-cmake-windows/` | CMake installation workflow |

## Local review commands

Run from PowerShell in the repository root:

```powershell
pwsh ./tools/test-powershell-syntax.ps1
pwsh ./tools/test-markdown-links.ps1
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error
```

## Review checklist

- Scripts validate elevation or explain when it is not required.
- Scripts avoid silently weakening SSH or file permissions.
- Documentation states what changes are made to the host.
- README files exist in English and Russian for each toolkit when practical.
- CI checks scripts structurally without executing dangerous setup operations.
- Warning-level analyzer findings are visible but do not block the workflow unless promoted.

## Current next improvements

1. Add a standard template for new toolkits.
2. Add a safety review checklist for scripts that modify system settings.
3. Add `-WhatIf` or dry-run behavior where practical.
4. Add a changelog for user-visible toolkit changes.
