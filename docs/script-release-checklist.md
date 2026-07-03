# Script Release Checklist

Use this checklist before promoting a PowerShell script as a reusable toolkit in `script-toolbox`.

## Safety gates

| Gate | Required evidence |
|---|---|
| No hidden destructive action | README states what the script changes and which files/services/accounts are touched. |
| Explicit parameters | Important values are passed as parameters or clearly documented defaults. |
| Elevation check | Scripts that need administrator rights fail early with a clear message. |
| Dry-run or validation path | When practical, the script can validate prerequisites before making changes. |
| Post-run verification | The script checks that the intended tool/service/configuration is actually available after execution. |
| Rollback note | The README explains how to inspect or undo the main change where rollback is realistic. |
| SSH safety | Remote-access changes warn the user to keep an active console/RDP session until login is confirmed. |

## Repository quality gates

Run from the repository root:

```powershell
pwsh -File tools/test-powershell-syntax.ps1
pwsh -File tools/test-markdown-links.ps1
Invoke-ScriptAnalyzer -Path . -Recurse
```

The GitHub Actions workflow is expected to fail on syntax errors and analyzer error-level findings. Warning-level findings may remain visible when they are consciously accepted and documented.

## Documentation gates

Every new toolkit should include:

- English README;
- Russian README when the toolkit is user-facing;
- quick-start command;
- parameter table or parameter examples;
- prerequisites;
- what the script changes;
- expected successful output;
- troubleshooting notes;
- safety notes for production or remote systems.

## Review decision

Use clear status wording:

```text
Accepted for repository use: syntax check, Markdown link check and ScriptAnalyzer have passed; documentation describes prerequisites, changes, safety notes and verification steps.
```

Or:

```text
Not ready for release: the script works locally, but the README does not yet describe safety impact, prerequisites and post-run verification.
```
