<#
.SYNOPSIS
    Slices supabase/admin_roles_and_rls.sql into one file per numbered section.

.DESCRIPTION
    The Supabase SQL Editor sends the whole editor buffer as a single request,
    which is what times out on a long script. This writes each numbered section
    to its own file under supabase/.chunks/ so it can be pasted and run one
    section at a time.

    The chunks are generated from the canonical SQL file on every run, so they
    cannot drift out of sync with it. Re-run this after editing the migration;
    do not edit anything in .chunks/ by hand.

    Sections are ordered and must be run 01 -> 10: later sections call
    is_admin() and the audit triggers from earlier ones. Each section is
    independently re-runnable, so a half-finished run is safe to repeat.

.EXAMPLE
    .\scripts\split_admin_sql.ps1
#>
[CmdletBinding()]
param(
    [string]$Source = 'supabase\admin_roles_and_rls.sql',
    [string]$OutDir = 'supabase\.chunks'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Source)) {
    throw "Source not found: $Source (run this from the project root)"
}

$lines = Get-Content -LiteralPath $Source

# A real section header is `-- 1. Title` with exactly one space. The table of
# contents in the file's leading comment block is indented (`--   1. Title`),
# so the single space is what keeps the two apart.
$headers = for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^-- \d+\. ') { $i }
}

if ($headers.Count -eq 0) {
    throw 'No numbered section headers found - has the migration been reworded?'
}

if (Test-Path $OutDir) {
    Remove-Item -LiteralPath $OutDir -Recurse -Force
}
New-Item -ItemType Directory -Path $OutDir | Out-Null

# The file's leading comment block is preamble, not a section. It stops one
# line short of the first banner, which section 1 claims - otherwise the
# banner is written to two files.
$firstBanner = $headers[0] - 1
$preamble = $lines[0..($firstBanner - 1)]
Set-Content -LiteralPath (Join-Path $OutDir '00_preamble.sql') -Value $preamble

for ($n = 0; $n -lt $headers.Count; $n++) {
    $start = $headers[$n]
    # Pull in the `===` banner line above the title so each chunk is readable
    # on its own.
    if ($start -gt 0 -and $lines[$start - 1] -match '^-- =+$') {
        $start--
    }

    # Stop one line before the *next* section's banner. Ending on the banner
    # instead would write every banner to two files.
    $end = if ($n -lt $headers.Count - 1) { $headers[$n + 1] - 2 } else { $lines.Count - 1 }

    $slug = ($lines[$headers[$n]] -replace '^--\s*\d+\.\s*', '') `
        -replace '[^A-Za-z0-9]+', '_' `
        -replace '^_+|_+$', ''

    $name = '{0:d2}_{1}.sql' -f ($n + 1), $slug.ToLower()
    $chunk = $lines[$start..$end]
    $count = $chunk.Count

    Set-Content -LiteralPath (Join-Path $OutDir $name) -Value $chunk
    Write-Host ('{0,-46} {1,5} lines' -f $name, $count)
}

Write-Host ''
Write-Host ("Wrote {0} sections to {1}" -f $headers.Count, $OutDir)
Write-Host 'Run them in numeric order. Each is safe to re-run.'
