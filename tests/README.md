# Tests

This directory is reserved for Pester tests.

`pwsh -NoProfile -File tools/test-ssh-config.ps1` already tests the SSH config
transformations without Pester: it extracts only three pure functions from the
AST, checks global/Match scope and idempotence, and never invokes the installer,
changes accounts/ACLs/services, or writes system configuration. This is not an
end-to-end dry-run of the setup script; a disposable VM is still required for that.

Recommended structure:

```text
tests/
├─ smoke.Tests.ps1
└─ toolkit-name.Tests.ps1
```

Initial test priorities:

1. script parsing without syntax errors;
2. parameter validation behavior;
3. dry-run or no-op checks where supported;
4. path and prerequisite detection helpers;
5. documentation examples that can be executed safely in a disposable VM.

CI already runs static analysis. Add Pester tests here when a toolkit has logic that can be validated without changing the host system.
