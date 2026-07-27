# dcsctp4j
The sctp4j project creates a JNI wrapper around the dcsctp library from libWebRTC.

## Building with Java changes only

To avoid having to build all native libraries,
execute `resources/fetch-maven.sh` to download and extract the native binaries
from the latest release on the Jitsi Maven Repository.

## Building the native libraries
The JNI lib will need to be rebuilt if there is a change in the WebRTC version or a change in the JNI wrapper
C++ files.

### A note on WebRTC
Because the checked-out Google source repositories are large, the build scripts provide an option to use
already checked-out versions of DepotTools and WebRTC.  Pass the path name of the these checkouts to the
build scripts; the DepotTools repository will be updated to the latest version, and the WebRTC repository
to the version specified in `resources/WebRTC-revision.txt`.

### Ubuntu

Prerequisites:

- OpenJDK 11 (or newer)
- Maven
- CMake
- Git
- APT packages `build-essential`, `g++-aarch64-linux-gnu`, `g++-powerpc64le-linux-gnu` and their dependencies

* Clone the project
* Update the SimpleJNI subproject with
```
$ git submodule update --init
```
* Build the JNI headers
```
$ mvn compile
```
* Check out WebRTC and build the libraries (adjusting the paths to DepotTools and WebRTC as desired)

```
$ resources/ubuntu-build-all.sh ~/DepotTools ~/WebRTC
```

> This will automatically check out
[Google DepotTools](https://www.chromium.org/developers/how-tos/install-depot-tools/) and
[WebRTC](https://webrtc.github.io/webrtc-org/native-code/development/); the
latter of these is quite large, so if this is your first checkout make sure
you have enough disk space and be prepared to wait for some time.

### Windows

Prerequisites:

- OpenJDK 11 (or newer)
- Maven
- CMake
- Git
- Visual Studio 2019 or 2022, with the "Desktop development with C++" workload.
  Newer Visual Studio releases will not work on their own: the pinned WebRTC
  revision only knows how to drive the 2019 and 2022 toolchains. Having a newer
  Visual Studio installed alongside one of those is fine, and the build scripts
  will find the 2022-generation install automatically.
- Windows SDK version **10.0.22621.0**, including the "Debugging Tools for
  Windows" component. This exact version is hardcoded in WebRTC's
  `build/vs_toolchain.py`, so a newer SDK alone is not enough. Without the
  debugging tools the build stops with a message about a missing
  `dbghelp.dll`. Both can be added from the Visual Studio Installer, under
  "Individual components".

Before you start:

* Enable Git long path support, or the WebRTC checkout will fail on paths longer
  than `MAX_PATH`:
```
> git config --global core.longpaths true
```
* Enable [Win32 long paths](https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation)
  in Windows itself, via Group Policy or by setting `LongPathsEnabled` to `1` under
  `HKLM\SYSTEM\CurrentControlSet\Control\FileSystem`.
* Set `JAVA_HOME` to your JDK installation, for example:
```
> $env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17.0.17.10-hotspot"
```

The build scripts are PowerShell, and are unsigned, so either run them from a
session started with `powershell -ExecutionPolicy Bypass`, or allow them for the
current session with:
```
> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

* Clone the project
* Update the SimpleJNI subproject with
```
> git submodule update --init
```
* Build the JNI headers
```
> mvn compile
```
* Check out WebRTC and build the libraries (adjusting the paths to DepotTools and WebRTC as desired)
```
> resources\windows-build-all.ps1 -DepotToolsDir C:\DepotTools -WebRtcDir C:\WebRTC
```

> This will automatically check out
[Google DepotTools](https://www.chromium.org/developers/how-tos/install-depot-tools/) and
[WebRTC](https://webrtc.github.io/webrtc-org/native-code/development/); the
latter of these is quite large, so if this is your first checkout make sure
you have enough disk space and be prepared to wait for some time.

> Keep the DepotTools and WebRTC paths short and close to the drive root. Deeply
nested paths are a common cause of build failures on Windows.

The scripts set `DEPOT_TOOLS_WIN_TOOLCHAIN=0` so that DepotTools uses your locally
installed Visual Studio rather than Google's internal toolchain package, which is
not available outside Google.

They also locate your Visual Studio with `vswhere` and export it as
`vs2022_install`. WebRTC only looks for Visual Studio in its default install
location, so an install placed anywhere else — a Build Tools install under
`C:\Program Files (x86)`, for instance — is otherwise invisible to it and the
build fails with "No supported Visual Studio can be found". Set `vs2022_install`
or `vs2019_install` yourself beforehand to override the detection.

To build a single architecture, or to pass build options, call the per-architecture
script directly:
```
> resources\windows-build.ps1 -JavaHome $env:JAVA_HOME -DepotToolsDir C:\DepotTools `
      -WebRtcDir C:\WebRTC [-Arch x86-64] [-VerboseBuild] [-DebugBuild]
```

Supported values for `-Arch` are `x86-64` and `arm64`; if omitted it defaults to the
host system's architecture. Only `x86-64` is built by `windows-build-all.ps1`; `arm64`
is untested.

The resulting `dcsctp4j.dll` is installed into `src\main\resources\win32-x86-64`,
matching the name JNA's `Platform.RESOURCE_PREFIX` uses to locate it inside the jar.

### macOS
- OpenJDK 11 (or newer)
- XCode
- Maven
- CMake

* Clone the project
* Update the SimpleJNI subproject with
```
$ git submodule update --init
```
* Build the JNI headers
```
$ mvn compile
```
* Check out WebRTC and build the libraries (adjusting the paths to DepotTools and WebRTC as desired)
```
$ resources/macos-build-all.sh ~/DepotTools ~/WebRTC
```

> This will automatically check out
[Google DepotTools](https://www.chromium.org/developers/how-tos/install-depot-tools/) and
[WebRTC](https://webrtc.github.io/webrtc-org/native-code/development/); the
latter of these is quite large, so if this is your first checkout make sure
you have enough disk space and be prepared to wait for some time.
