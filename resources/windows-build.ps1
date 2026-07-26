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
    # Path to the Java installation
    [Parameter(Mandatory = $true)][string] $JavaHome,
    # Directory containing Google depot tools
    [Parameter(Mandatory = $true)][string] $DepotToolsDir,
    # Directory containing the WebRTC source
    [Parameter(Mandatory = $true)][string] $WebRtcDir,
    # Architecture to build for
    [Parameter(Mandatory = $true)]
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
# CMake's FindJNI consults the JAVA_HOME environment variable.
$env:JAVA_HOME = $JavaHome

$DepotToolsDir = (Resolve-Path -LiteralPath $DepotToolsDir).Path
$WebRtcDir = (Resolve-Path -LiteralPath $WebRtcDir).Path

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

$StartDir = $PWD.Path
# Multi-config generators run the install step from the build directory, so a
# relative CMAKE_INSTALL_PREFIX would not land at the project root.
$InstallPrefix = Join-Path $StartDir "src/main/resources/win32-$JnaArch"

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

Set-Location -LiteralPath $StartDir

$BuildDir = "cmake-build-windows-$GnArch"
if (Test-Path -LiteralPath $BuildDir)
{
    Remove-Item -Recurse -Force -LiteralPath $BuildDir
}

# CMake treats backslashes as escapes when these land in generated files, so hand it
# the forward-slash form of every path.
function ConvertTo-CMakePath { param([string] $Path) $Path -replace '\\', '/' }

$configureArgs = @(
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
