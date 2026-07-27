<#
.SYNOPSIS
    Build libdcsctp and dcsctp4j.dll for a single Windows architecture.
.DESCRIPTION
    Windows equivalent of resources/ubuntu-build.sh and resources/macos-build.sh.
    Assumes depot_tools and WebRTC are already checked out; see
    resources/checkout-webrtc.ps1 or resources/windows-build-all.ps1.
#>
[CmdletBinding()]
param(
    # Path to the Java installation. Auto-detected from JAVA_HOME, the registry or PATH if omitted.
    [string] $JavaHome,
    # Directory containing Google depot tools
    [Parameter(Mandatory = $true)][string] $DepotToolsDir,
    # Directory containing the WebRTC source
    [Parameter(Mandatory = $true)][string] $WebRtcDir,
    # Architecture to build for. Defaults to the host system's architecture.
    [ValidateSet('x86-64', 'x86_64', 'amd64', 'x64', 'arm64', 'aarch64')]
    [string] $Arch,
    # Print compiler invocations
    [switch] $VerboseBuild,
    # Build without optimization. Not named -Debug: that is a reserved common parameter.
    [switch] $DebugBuild
)

$ErrorActionPreference = 'Stop'

function Invoke-Checked
{
    param([string] $Exe, [string[]] $Arguments)
    & $Exe @Arguments
    if ($LASTEXITCODE -ne 0)
    {
        throw "'$Exe $($Arguments -join ' ')' failed with exit code $LASTEXITCODE"
    }
}

if (-not $Arch)
{
    $Arch = switch ($env:PROCESSOR_ARCHITECTURE)
    {
        'ARM64' { 'arm64' }
        default { 'x86-64' }
    }
    Write-Host "-Arch not specified; defaulting to the host architecture ($Arch)."
}

if (-not $JavaHome)
{
    # Registry first (how JDK installers register themselves), then java.exe on PATH,
    # whose grandparent directory is the JDK root.
    $JavaHome = Get-ItemProperty -Path 'HKLM:\SOFTWARE\JavaSoft\JDK\*' -ErrorAction SilentlyContinue |
        Sort-Object PSChildName |
        Select-Object -Last 1 -ExpandProperty JavaHome -ErrorAction SilentlyContinue
    if (-not $JavaHome)
    {
        $java = Get-Command java.exe -ErrorAction SilentlyContinue
        if ($java) { $JavaHome = Split-Path -Parent (Split-Path -Parent $java.Source) }
    }
    # jni.h is what the build actually needs, so reject a JRE-only directory.
    if (-not $JavaHome -or -not (Test-Path -LiteralPath (Join-Path $JavaHome 'include\jni.h')))
    {
        throw '-JavaHome was not specified and could not be auto-detected; set it to a JDK installation.'
    }
    # Every JDK ships a "release" file with a JAVA_VERSION property; fall back to just
    # the path if it is somehow missing.
    $releaseFile = Join-Path $JavaHome 'release'
    $version = $null
    if (Test-Path -LiteralPath $releaseFile)
    {
        $versionLine = Get-Content -LiteralPath $releaseFile | Where-Object { $_ -match '^JAVA_VERSION=' }
        if ($versionLine) { $version = ($versionLine -replace '^JAVA_VERSION=', '') -replace '"', '' }
    }
    if ($version)
    {
        Write-Host "-JavaHome not specified; defaulting to detected JDK $version at $JavaHome."
    }
    else
    {
        Write-Host "-JavaHome not specified; defaulting to the detected JDK at $JavaHome."
    }
}

# WebRTC's build/vs_toolchain.py recognizes only Visual Studio 2019 and 2022, and only
# in their default install locations. Newer Visual Studio releases, and installs placed
# elsewhere, make it fail with "No supported Visual Studio can be found". It honours a
# vs<year>_install environment variable, so locate a 2022-generation install ourselves
# and point it there.
function Set-VsToolchainEnv
{
    if ($env:vs2022_install -or $env:vs2019_install)
    {
        return
    }
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere))
    {
        return
    }
    # [17.0,18.0) is the 2022 generation: the newest this WebRTC revision can drive.
    $path = & $vswhere -products '*' -version '[17.0,18.0)' `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -latest -property installationPath
    if ($path)
    {
        $env:vs2022_install = $path
        Write-Host "Using Visual Studio at $path"
    }
}

switch ($Arch)
{
    { $_ -in 'x86-64', 'x86_64', 'amd64', 'x64' } {
        $JnaArch = 'x86-64'; $GnArch = 'x64'; $VsArch = 'x64'
    }
    { $_ -in 'arm64', 'aarch64' } {
        $JnaArch = 'aarch64'; $GnArch = 'arm64'; $VsArch = 'ARM64'
    }
}

if ($DebugBuild)
{
    $GnIsDebug = 'true'
    $BuildConfig = 'Debug'
}
else
{
    $GnIsDebug = 'false'
    $BuildConfig = 'RelWithDebInfo'
}

$env:DEPOT_TOOLS_WIN_TOOLCHAIN = '0'
Set-VsToolchainEnv
# CMake's FindJNI consults the JAVA_HOME environment variable.
$env:JAVA_HOME = $JavaHome

$DepotToolsDir = (Resolve-Path -LiteralPath $DepotToolsDir).Path
$WebRtcDir = (Resolve-Path -LiteralPath $WebRtcDir).Path
$ProjectDir = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path

# They may have specified the gclient directory, not the src checkout subdirectory
if ((-not (Test-Path -LiteralPath (Join-Path $WebRtcDir '.git'))) -and
    (Test-Path -LiteralPath (Join-Path $WebRtcDir '.gclient')) -and
    (Test-Path -LiteralPath (Join-Path $WebRtcDir 'src\.git')))
{
    $WebRtcDir = Join-Path $WebRtcDir 'src'
}

$WebRtcBuild = "out/windows-$GnArch"
$WebRtcObj = Join-Path $WebRtcDir $WebRtcBuild

$env:PATH = "$DepotToolsDir;$env:PATH"

# Multi-config generators run the install step from the build directory, so a
# relative CMAKE_INSTALL_PREFIX would not land at the project root.
$InstallPrefix = Join-Path $ProjectDir "src/main/resources/win32-$JnaArch"

Push-Location -LiteralPath $WebRtcDir
try
{
    if (Test-Path -LiteralPath $WebRtcBuild)
    {
        Remove-Item -Recurse -Force -LiteralPath $WebRtcBuild
    }

    # Write args.gn rather than passing --args=, whose embedded quotes and spaces do
    # not survive being re-parsed by cmd.exe.
    New-Item -ItemType Directory -Force -Path $WebRtcBuild | Out-Null
    @(
        'use_custom_libcxx=false'
        "target_cpu=`"$GnArch`""
        "is_debug=$GnIsDebug"
        'symbol_level=2'
    ) | Set-Content -LiteralPath (Join-Path $WebRtcBuild 'args.gn') -Encoding ascii

    Invoke-Checked (Join-Path $DepotToolsDir 'gn.bat') @('gen', $WebRtcBuild)

    $ninjaArgs = @()
    if ($VerboseBuild) { $ninjaArgs += '-v' }
    $ninjaArgs += @('-C', $WebRtcBuild, 'dcsctp')
    Invoke-Checked (Join-Path $DepotToolsDir 'ninja.bat') $ninjaArgs
}
finally
{
    Pop-Location
}

Set-Location -LiteralPath $ProjectDir

$BuildDir = "cmake-build-windows-$GnArch"
if (Test-Path -LiteralPath $BuildDir)
{
    Remove-Item -Recurse -Force -LiteralPath $BuildDir
}

# CMake treats backslashes as escapes when these land in generated files, so hand it
# the forward-slash form of every path.
function ConvertTo-CMakePath { param([string] $Path) $Path -replace '\\', '/' }

$configureArgs = @(
    '-S', (ConvertTo-CMakePath $ProjectDir),
    '-B', $BuildDir,
    "-DJAVA_HOME=$(ConvertTo-CMakePath $JavaHome)",
    "-DCMAKE_INSTALL_PREFIX=$(ConvertTo-CMakePath $InstallPrefix)",
    "-DWEBRTC_DIR=$(ConvertTo-CMakePath $WebRtcDir)",
    "-DWEBRTC_OBJ=$(ConvertTo-CMakePath $WebRtcObj)",
    "-DCMAKE_BUILD_TYPE=$BuildConfig"
)
# CMake defaults to the newest installed Visual Studio generator, which needs -A to
# select the target architecture. Single-config generators (e.g. Ninja) do not take it.
if ((-not $env:CMAKE_GENERATOR) -or ($env:CMAKE_GENERATOR -like 'Visual Studio*'))
{
    $configureArgs += @('-A', $VsArch)
}
Invoke-Checked 'cmake' $configureArgs

$buildArgs = @('--build', $BuildDir, '--config', $BuildConfig, '--target', 'install',
               '--parallel', [Environment]::ProcessorCount)
if ($VerboseBuild) { $buildArgs += '--verbose' }
Invoke-Checked 'cmake' $buildArgs
