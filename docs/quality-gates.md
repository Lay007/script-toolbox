# Quality gates

Use these checks before changing or releasing a toolkit.

## Required for every change

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error
```

## Recommended for script changes

- Run the script in a disposable Windows VM.
- Prefer a non-production user and non-production SSH key.
- Keep an active console, RDP, or recovery path for SSH-related changes.
- Record the exact PowerShell version and Windows build used for validation.
- Update the toolkit README when parameters, defaults, or side effects change.

## Recommended for new toolkits

- Add English and Russian usage notes.
- Include a minimal example command.
- Explain what the script changes on the host.
- Add rollback or manual recovery notes where relevant.
- Add Pester tests for pure helper functions where possible.

## Release checklist

- Static analysis passes.
- README examples match the script parameters.
- No private paths, keys, hostnames, or credentials are committed.
- Risky actions require explicit parameters or clear confirmation.
- The script prints actionable errors for missing prerequisites.
