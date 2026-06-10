# Repository quality tools

This directory contains lightweight repository checks used by CI and local review.

These scripts are intentionally safe: they inspect files and documentation, but they do not execute setup scripts that modify Windows configuration.

## Scripts

| Script | Purpose | Executes setup scripts? |
|---|---|---|
| `test-powershell-syntax.ps1` | Parses all repository `.ps1` files with the PowerShell AST parser | No |
| `test-markdown-links.ps1` | Checks relative Markdown links in repository documentation | No |

## Local usage

Run PowerShell syntax checks:

```powershell
pwsh -NoProfile -File tools/test-powershell-syntax.ps1
```

Run Markdown relative link checks:

```powershell
pwsh -NoProfile -File tools/test-markdown-links.ps1
```

## CI role

The tools are used by the PowerShell lint workflow before deeper static analysis. They provide fast feedback for syntax errors and stale local documentation links.

See also [CI quality gates](../docs/ci-quality-gates.md).
