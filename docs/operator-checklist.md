# Operator Checklist

This checklist helps an operator run `script-toolbox` utilities in a controlled and reviewable way.

## Before running a script

| Check | Done |
|---|---|
| I know which toolkit I am going to run | [ ] |
| I have read the toolkit README | [ ] |
| I understand whether elevated permissions are required | [ ] |
| I know which files or settings may be changed | [ ] |
| I have a recovery plan for important local configuration | [ ] |
| I have closed unrelated terminals or tools that may lock files | [ ] |
| I have copied important command output or enabled logging if needed | [ ] |

## Environment record

Record these values when the run is important:

| Field | Value |
|---|---|
| Date / time | TBD |
| Operator | TBD |
| Hostname | TBD |
| Windows version | TBD |
| PowerShell version | TBD |
| Script path | TBD |
| Script commit | TBD |
| Execution mode | normal / dry run / validation only |

## Recommended run discipline

1. Open a clean terminal.
2. Move to the toolkit directory.
3. Review the command before pressing Enter.
4. Run the script once.
5. Save the final summary.
6. Run the documented verification command.
7. Record any manual follow-up actions.

## After running a script

| Check | Done |
|---|---|
| Final script status was reviewed | [ ] |
| Verification command was executed | [ ] |
| Any changed paths were recorded | [ ] |
| Any generated logs were saved | [ ] |
| Any warnings were copied into notes | [ ] |
| The system was not left in a half-configured state | [ ] |

## Failure notes

If a run fails, record:

- the exact script command;
- the first visible error;
- whether the script stopped or continued;
- which verification step failed;
- what was changed before the failure;
- what action was taken next.

## Review questions

Before considering a setup complete, answer:

1. What did this script change?
2. How was success verified?
3. What evidence would another engineer need to reproduce this setup?
4. What would be the safest way to undo or repeat the procedure?

## Practical rule

Treat workstation setup as engineering work, not as a one-time manual action. A good setup run should be repeatable, inspectable, and understandable after the fact.
