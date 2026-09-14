[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$expectedPayloadSha256 = '1229A01115E66DB56749C0326744CAF32F0E78A67E8B76311361603AE1D75E34'
$payload = Join-Path $PSScriptRoot 'payload\BrokenPipePayload.zip'
$project = Join-Path $PSScriptRoot 'BrokenPipe.vcxproj'
$output = Join-Path $PSScriptRoot 'x64\Release\BrokenPipe.exe'

if (-not (Test-Path -LiteralPath $payload -PathType Leaf)) {
    throw 'Missing payload\BrokenPipePayload.zip. Keep the payload directory beside build.ps1.'
}
$payloadHash = (Get-FileHash -LiteralPath $payload -Algorithm SHA256).Hash.ToUpperInvariant()
if ($payloadHash -cne $expectedPayloadSha256) {
    throw "Payload SHA-256 mismatch. Expected $expectedPayloadSha256, observed $payloadHash."
}

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$msbuild = $null
if (Test-Path -LiteralPath $vswhere) {
    $msbuild = @(
        & $vswhere -latest -products '*' -requires Microsoft.Component.MSBuild `
            -find 'MSBuild\**\Bin\MSBuild.exe'
    ) | Select-Object -First 1
}
if (-not $msbuild) {
    $command = Get-Command MSBuild.exe -ErrorAction SilentlyContinue
    if ($command) { $msbuild = $command.Source }
}
if (-not $msbuild) {
    throw 'Visual Studio 2022 with Desktop development with C++ is required.'
}

& $msbuild $project '/m' '/t:Rebuild' '/p:Configuration=Release' '/p:Platform=x64'
if ($LASTEXITCODE -ne 0) { throw "MSBuild failed with exit code $LASTEXITCODE." }
if (-not (Test-Path -LiteralPath $output -PathType Leaf)) { throw 'BrokenPipe.exe was not produced.' }

[pscustomobject]@{
    executable = $output
    length = (Get-Item -LiteralPath $output).Length
    sha256 = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToUpperInvariant()
    embedded_payload_sha256 = $payloadHash
}
