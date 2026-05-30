# Contributing

Thank you for improving `script-toolbox`.

## Local checks

Before opening a pull request, run the same basic checks used by CI:

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error
```

If a `tests` directory exists for a toolkit, run its Pester tests as well:

```powershell
Invoke-Pester -Path tests -Output Detailed
```

## Script quality rules

- Keep scripts focused on one setup task.
- Prefer explicit parameters over hidden assumptions.
- Validate prerequisites before changing the system.
- Print clear status messages and actionable errors.
- Update the toolkit README when behavior changes.
- Avoid embedding secrets, private paths, or machine-specific values.

## Documentation rules

Each substantial toolkit should include:

- purpose and supported platform;
- prerequisites;
- example command lines;
- what the script changes;
- rollback or safety notes where relevant.
