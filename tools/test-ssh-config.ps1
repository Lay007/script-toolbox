[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot '../config-ssh-client-windows/setup-windows-openssh-keyonly.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path -LiteralPath $source).Path, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'SSH script has parse errors.' }

# Load ONLY pure in-memory transformations; never execute the setup entrypoint.
foreach ($name in @('Get-FirstMatchIndex', 'Set-GlobalDirective', 'Ensure-MatchGroupAdministratorsAuthorizedKeys')) {
    $definition = $ast.FindAll({ param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
    }, $false) | Where-Object Name -EQ $name
    if (@($definition).Count -ne 1) { throw "Expected one function: $name" }
    . ([scriptblock]::Create($definition.Extent.Text))
}

$lines = [System.Collections.Generic.List[string]]::new()
@('#PasswordAuthentication yes', 'PasswordAuthentication yes', 'Port 22',
  'Match User guest', '    PasswordAuthentication yes') | ForEach-Object { $lines.Add($_) }
Set-GlobalDirective -Lines $lines -Name 'PasswordAuthentication' -Value 'no'
if (($lines -join '|') -ne 'Port 22|PasswordAuthentication no|Match User guest|    PasswordAuthentication yes') {
    throw 'Global replacement changed a Match block or retained duplicate directives.'
}
$once = $lines -join '|'
Set-GlobalDirective -Lines $lines -Name 'PasswordAuthentication' -Value 'no'
if (($lines -join '|') -ne $once) { throw 'Global replacement is not idempotent.' }

Ensure-MatchGroupAdministratorsAuthorizedKeys -Lines $lines
$once = $lines -join '|'
Ensure-MatchGroupAdministratorsAuthorizedKeys -Lines $lines
if (($lines -join '|') -ne $once) { throw 'Administrator Match insertion is not idempotent.' }
if (($lines | Where-Object { $_ -eq 'Match Group administrators' }).Count -ne 1) {
    throw 'Expected exactly one administrator block.'
}
Write-Host 'PASS: SSH config scope, duplicate removal and idempotence; no host changes.'
