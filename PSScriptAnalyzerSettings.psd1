@{
    Severity = @('Error', 'Warning')
    ExcludeRules = @(
        # This repository uses engineering-style helper verbs such as Ensure-* for
        # idempotent setup routines. Keep diagnostics strict for other rules while
        # avoiding noise from naming-only warnings.
        'PSUseApprovedVerbs'
    )
}
