# Engineering Safety Model

This repository contains scripts that may change Windows system configuration, user accounts, SSH access, PATH variables, developer tools and local permissions. The goal is to make these changes repeatable and reviewable instead of hidden inside manual setup steps.

## Safety principles

| Principle | How it should appear in scripts |
|---|---|
| Explicit intent | Important changes are controlled by named parameters rather than hidden defaults. |
| Early validation | Scripts check elevation, required tools, input paths and operating assumptions before changing the system. |
| Fail fast | Invalid input or unsafe state should stop execution with a clear error. |
| Idempotence | Re-running a script should avoid duplicating config blocks or corrupting existing settings. |
| Least surprise | Scripts should print what they are changing and where the relevant files are located. |
| Recovery path | Risky operations should preserve enough context for rollback or manual repair. |

## Recommended script checklist

Before adding or modifying a script, check that it answers these questions:

- What exact system state does the script create or modify?
- Does it require elevated PowerShell?
- What user account or profile path does it touch?
- Which files are created, replaced or edited?
- Does it validate downloaded files before running installers?
- Can it be run twice without breaking configuration?
- Does the README include a minimal example and a production-style example?
- Does the README include post-run verification commands?

## SSH-related scripts

For scripts that modify SSH access:

- Keep an active console, RDP or out-of-band access session while testing.
- Avoid disabling password access until key-based login has been verified.
- Apply strict ACLs to private keys and `authorized_keys` files.
- Keep managed config blocks clearly marked so they can be updated safely.
- Document the exact host, user and key paths used by the example.

## Installer-related scripts

For scripts that download and run installers:

- Prefer official package managers or official release-history URLs.
- Validate that the downloaded file is not an HTML error page or short-link response.
- Check file size and digital signature where practical.
- Support download-only mode for offline review or controlled deployment.
- Print the resolved installer path and install arguments before execution.

## Documentation standard

Every toolkit should ideally include:

1. English guide.
2. Russian guide.
3. Parameter table.
4. Quick-start command.
5. Post-run verification commands.
6. Troubleshooting section.
7. Rollback or manual recovery notes.

This keeps the repository useful both as a working toolbox and as a professional engineering portfolio artifact.
