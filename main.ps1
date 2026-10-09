<#
.SYNOPSIS
    Runs the CyberPatriot Windows audit scripts from one entry point.

.DESCRIPTION
    By default, runs read-only security audits and saves each script's console
    output, plus a run summary, to a timestamped report directory.

    Full mode additionally runs defender_update.ps1 (updates signatures) and
    service_hardening.ps1 (may stop/disable services). Full mode MUST be
    explicitly approved using -AllowChanges. Service hardening prompts
    individually unless -AutoDisableServices is also supplied.

    The Examples hardening scripts and Templates are intentionally NOT run:
    they contain context-dependent or sample settings that can break required
    services or change access. Review the competition README and current rules
    before using any automation.

.EXAMPLE
    .\main.ps1
    Run audits only, saving reports under Documents\CyberPatriotReports.

.EXAMPLE
    .\main.ps1 -Mode List
    Show what this launcher would run without executing anything.

.EXAMPLE
    .\main.ps1 -ListFirewallRules -IncludeExampleAudit
    Run audits with an expanded firewall report and sample user audit.

.EXAMPLE
    .\main.ps1 -Mode Full -AllowChanges
    Run audits, update Defender signatures, and interactively review services.

.EXAMPLE
    .\main.ps1 -Mode Full -AllowChanges -AutoDisableServices
    DANGEROUS: Automatically stop/disable services targeted by the source script.
    Only use after checking each required service in the competition README.
#>
[CmdletBinding()]
param(
    [ValidateSet('Audit', 'Full', 'List')]
    [string]$Mode = 'Audit',

    [string]$OutputRoot = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'CyberPatriotReports'),

    [switch]$AllowChanges,
    [switch]$AutoDisableServices,
    [switch]$ListFirewallRules,
    [switch]$IncludeExampleAudit
)

$ErrorActionPreference = 'Stop'

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'This script requires Windows.'
}
if ($PSVersionTable.PSVersion.Major -lt 5) {
    throw 'PowerShell 5.1 or later is recommended to run the Windows security audit scripts.'
}
if ($Mode -eq 'Full' -and -not $AllowChanges) {
    throw 'Full mode can change Windows settings. Re-run with -Mode Full -AllowChanges after reviewing the competition README.'
}
if ($AutoDisableServices -and ($Mode -ne 'Full' -or -not $AllowChanges)) {
    throw '-AutoDisableServices requires -Mode Full -AllowChanges.'
}
if ($AllowChanges -and $Mode -ne 'Full') {
    throw '-AllowChanges only applies to -Mode Full.'
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($Mode -eq 'Full' -and -not $isAdmin) {
    throw 'Full mode requires an elevated PowerShell window (Run as Administrator).'
}
if (-not $isAdmin) {
    Write-Warning 'Not running as Administrator. Some audit details may be incomplete.'
}

$engine = if ($PSVersionTable.PSEdition -eq 'Desktop') {
    Join-Path $PSHOME 'powershell.exe'
} else {
    (Get-Command -Name pwsh.exe -ErrorAction Stop).Source
}

$runId = (Get-Date -Format 'yyyyMMdd_HHmmss') + '_' + [guid]::NewGuid().ToString('N').Substring(0, 6)
$reportFolder = Join-Path $OutputRoot $runId

function New-RunTask {
    param(
        [string]$Name,
        [string]$File,
        [string[]]$Arguments = @(),
        [bool]$Interactive = $false
    )
    return @{
        Name = $Name
        File = $File
        Arguments = $Arguments
        Interactive = $Interactive
    }
}

# Each listed audit reads Windows settings only; output files are written in
# the chosen reports folder. Some audits intentionally overlap for cross-checks.
$firewallArgs = @()
if ($ListFirewallRules) { $firewallArgs = @('-ListEnabledRules') }

$tasks = @(
    (New-RunTask -Name 'baseline_system_snapshot' -File 'baseline_system_snapshot.ps1' -Arguments @('-OutputDir', (Join-Path $reportFolder 'baseline')))
    (New-RunTask -Name 'audit_users'             -File 'audit_users.ps1'             -Arguments @('-OutputDir', (Join-Path $reportFolder 'users')))
    (New-RunTask -Name 'user_audit'              -File 'user_audit.ps1')
    (New-RunTask -Name 'audit_services'          -File 'audit_services.ps1'          -Arguments @('-OutputDir', (Join-Path $reportFolder 'services')))
    (New-RunTask -Name 'audit_network'           -File 'audit_network.ps1'           -Arguments @('-OutputFile', (Join-Path $reportFolder 'network.txt')))
    (New-RunTask -Name 'audit_startup'           -File 'audit_startup.ps1'           -Arguments @('-OutputFile', (Join-Path $reportFolder 'startup.txt')))
    (New-RunTask -Name 'startup_audit'           -File 'startup_audit.ps1')
    (New-RunTask -Name 'firewall_check'          -File 'firewall_check.ps1'           -Arguments $firewallArgs)
    (New-RunTask -Name 'policy_check'            -File 'policy_check.ps1')
    (New-RunTask -Name 'share_audit'             -File 'share_audit.ps1')
)

if ($IncludeExampleAudit) {
    $tasks += New-RunTask -Name 'example_audit_local_users' -File 'Examples\Audit-LocalUsers.ps1'
}

if ($Mode -eq 'Full') {
    # Both are deliberately opt-in because they are NOT read-only operations.
    $tasks += New-RunTask -Name 'defender_update' -File 'defender_update.ps1'
    $serviceArgs = if ($AutoDisableServices) { @('-AutoDisable') } else { @() }
    $tasks += New-RunTask -Name 'service_hardening' -File 'service_hardening.ps1' -Arguments $serviceArgs -Interactive (-not $AutoDisableServices)
}

Write-Host 'CyberPatriot Windows Script Runner' -ForegroundColor Cyan
Write-Host '================================='
Write-Host ('Mode: {0}' -f $Mode)
Write-Host ('Tasks: {0}' -f $tasks.Count)
Write-Host 'Read the competition README and rules before running scripts on an image.'

if ($Mode -eq 'List') {
    Write-Host ''
    Write-Host 'Audit tasks that would run:' -ForegroundColor Yellow
    foreach ($task in $tasks) {
        Write-Host ('  - {0}' -f $task.File)
    }
    Write-Host ''
    Write-Host 'Full mode also runs defender_update.ps1 and service_hardening.ps1.'
    Write-Host 'Examples (other than optional user audit) and Templates are not run.'
    return
}

if ($Mode -eq 'Full') {
    Write-Warning 'Full mode will attempt a Defender signature update and may disable services.'
    if ($AutoDisableServices) {
        Write-Warning 'AUTO-DISABLE IS ENABLED: service_hardening.ps1 will not prompt per service.'
    } else {
        Write-Host 'Service hardening will ask before each service change.' -ForegroundColor Yellow
    }
}

New-Item -ItemType Directory -Path $reportFolder -Force -ErrorAction Stop | Out-Null
Write-Host ('Reports: {0}' -f $reportFolder) -ForegroundColor Cyan
Write-Warning 'Audit reports may contain user names, network configuration and other sensitive system information. Keep them private.'

$results = @()
foreach ($task in $tasks) {
    $scriptPath = Join-Path $PSScriptRoot $task.File
    $logPath = Join-Path $reportFolder ($task.Name + '.log')
    $started = Get-Date

    Write-Host ''
    Write-Host ('[RUN] {0}' -f $task.File) -ForegroundColor Cyan

    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        Write-Warning ('Missing script: {0}' -f $scriptPath)
        $results += [pscustomobject]@{
            Task = $task.Name; Status = 'Missing'; ExitCode = 1
            DurationSeconds = 0; LogFile = $null
        }
        continue
    }

    $arguments = @('-NoLogo', '-NoProfile')
    if (-not $task.Interactive) {
        $arguments += '-NonInteractive'
    }
    $arguments += @('-File', $scriptPath)
    $arguments += @($task.Arguments)

    $exitCode = 1
    try {
        if ($task.Interactive) {
            # Live console needed for the source script's Read-Host prompts.
            # This task has no redirected log so the prompts stay visible.
            & $engine @arguments
            $exitCode = $LASTEXITCODE
            $logPath = $null
        } else {
            # Run in a child process so an exit statement in an audit
            # cannot terminate the orchestrator. Save full output per task.
            & $engine @arguments *>&1 | Out-File -FilePath $logPath -Width 300 -Encoding UTF8
            $exitCode = $LASTEXITCODE
        }
    } catch {
        Write-Warning ('Could not complete {0}: {1}' -f $task.File, $_.Exception.Message)
        $exitCode = 1
    }

    if ($null -eq $exitCode) { $exitCode = 1 }
    $status = if ($exitCode -eq 0) { 'Completed' } else { 'Failed' }
    $seconds = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
    $results += [pscustomobject]@{
        Task = $task.Name
        Status = $status
        ExitCode = $exitCode
        DurationSeconds = $seconds
        LogFile = $logPath
    }

    if ($exitCode -eq 0) {
        Write-Host ('[OK] {0} ({1}s)' -f $task.Name, $seconds) -ForegroundColor Green
    } else {
        Write-Warning ('[FAILED] {0} exited with {1}. Review its log and console output.' -f $task.Name, $exitCode)
    }
}

$summaryCsv = Join-Path $reportFolder 'summary.csv'
$results | Export-Csv -Path $summaryCsv -NoTypeInformation -Encoding UTF8

Write-Host ''
Write-Host 'Run Summary' -ForegroundColor Cyan
$results | Format-Table Task, Status, ExitCode, DurationSeconds -AutoSize
Write-Host ('Results saved in: {0}' -f $reportFolder)
Write-Host ('Summary CSV: {0}' -f $summaryCsv)
Write-Host 'Completed means the child script exited with code 0; it does NOT mean a system is secure or all checks passed.'

if (@($results | Where-Object { $_.Status -ne 'Completed' }).Count -gt 0) {
    exit 1
}
exit 0
