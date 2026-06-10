# Contributing

Thank you for improving `script-toolbox`.

This repository contains scripts that may change Windows system configuration, SSH settings, user accounts, PATH variables and developer tools. Contributions should therefore prioritize safety, clarity and repeatability.

## Contribution principles

- Keep scripts small and focused.
- Prefer explicit parameters over hidden assumptions.
- Validate inputs before changing system state.
- Make scripts idempotent where practical.
- Print what is being changed and where.
- Document verification and rollback steps.
- Update English and Russian documentation together when behavior changes.

## Script checklist

Before opening a pull request, check that the script answers these questions:

- Does it require elevated PowerShell?
- What files, users, services or PATH entries does it modify?
- Can it be run twice without duplicating configuration?
- Does it fail early on invalid input?
- Does it avoid hard-coded user-specific paths?
- Does it preserve enough information for manual recovery?
- Does it include post-run verification commands?

## Documentation checklist

Every toolkit should ideally include:

```text
<toolkit>/
  setup-*.ps1
  README-*.md
  README-*-ru.md
```

Documentation should include:

- purpose and scope;
- prerequisites;
- example command;
- parameter table;
- post-run verification;
- troubleshooting notes;
- rollback or manual recovery notes.

## PowerShell style

- Use named parameters for important behavior.
- Use `$ErrorActionPreference = 'Stop'` for setup scripts.
- Prefer `Join-Path` over manual path concatenation.
- Prefer clear errors over silent fallback behavior.
- Avoid downloading and executing remote code without validation.
- Keep comments focused on why, not on obvious syntax.

## Local checks

Before opening a pull request, run the same basic checks used by CI:

```powershell
pwsh -NoProfile -File tools/test-powershell-syntax.ps1
pwsh -NoProfile -File tools/test-markdown-links.ps1
```

For deeper analysis, run PSScriptAnalyzer with the repository settings:

```powershell
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force
Invoke-ScriptAnalyzer -Path . -Recurse -Settings PSScriptAnalyzerSettings.psd1
```

See [CI Quality Gates](./docs/ci-quality-gates.md) for the policy behind these checks.

If a `tests` directory exists for a toolkit, run its Pester tests as well.
