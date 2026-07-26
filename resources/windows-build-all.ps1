<#
.SYNOPSIS
    Check out WebRTC and build the native libraries for all Windows architectures.
.DESCRIPTION
    Windows equivalent of resources/ubuntu-build-all.sh and resources/macos-build-all.sh.
#>
[CmdletBinding()]
param(
    # Directory for Google depot tools (may exist already)
    [Parameter(Mandatory = $true)][string] $DepotToolsDir,
    # Directory for the WebRTC checkout (may exist already)
    [Parameter(Mandatory = $true)][string] $WebRtcDir
)

$ErrorActionPreference = 'Stop'

$ProjectDir = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$JavaVersion = 11
$Archs = @('x86-64')

function Invoke-Checked
{
    param([string] $Exe, [string[]] $Arguments)
    & $Exe @Arguments
    if ($LASTEXITCODE -ne 0)
    {
        throw "'$Exe $($Arguments -join ' ')' failed with exit code $LASTEXITCODE"
    }
}

$WebRtcRevision = (Get-Content -LiteralPath (Join-Path $ProjectDir 'resources/WebRTC-revision.txt') -Raw).Trim()
if (-not $WebRtcRevision)
{
    throw 'Could not find WebRTC revision'
}

$JavaHome = $env:JAVA_HOME
if (-not $JavaHome)
{
    # Registry first (how the JDK installers register themselves), then the java.exe
    # on PATH, whose grandparent is the JDK root.
    $JavaHome = Get-ItemProperty -Path 'HKLM:\SOFTWARE\JavaSoft\JDK\*' -ErrorAction SilentlyContinue |
        Sort-Object PSChildName |
        Select-Object -Last 1 -ExpandProperty JavaHome -ErrorAction SilentlyContinue
}
if (-not $JavaHome)
{
    $java = Get-Command java.exe -ErrorAction SilentlyContinue
    if ($java)
    {
        $JavaHome = Split-Path -Parent (Split-Path -Parent $java.Source)
    }
}
# jni.h is what the build actually needs, so reject a JRE-only directory.
if (-not $JavaHome -or -not (Test-Path -LiteralPath (Join-Path $JavaHome 'include\jni.h')))
{
    throw "Could not find a JDK; set JAVA_HOME in the environment to a JDK $JavaVersion or newer installation."
}

Push-Location -LiteralPath $ProjectDir
try
{
    Invoke-Checked 'mvn.cmd' @('compile') # Build SimpleJNI jnigen headers

    & (Join-Path $PSScriptRoot 'checkout-webrtc.ps1') `
        -DepotToolsDir $DepotToolsDir -WebRtcDir $WebRtcDir -Rev $WebRtcRevision

    foreach ($arch in $Archs)
    {
        & (Join-Path $PSScriptRoot 'windows-build.ps1') `
            -JavaHome $JavaHome -DepotToolsDir $DepotToolsDir -WebRtcDir $WebRtcDir -Arch $arch
    }
}
finally
{
    Pop-Location
}
