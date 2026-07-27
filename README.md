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
- Git, with `core.longpaths` enabled (`git config --global core.longpaths true`)
  and [Win32 long paths](https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation) enabled in Windows itself
- Visual Studio 2019 or 2022, with the "Desktop development with C++" workload
- Windows SDK **10.0.22621.0**, with the "Debugging Tools for Windows" component
  (both from the Visual Studio Installer, under "Individual components")

Before you start: 
* allow the (unsigned) PowerShell scripts to run:
```
> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
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
you have enough disk space and be prepared to wait for some time. Keep both paths
short and close to the drive root — deeply nested paths are a common cause of
build failures on Windows.

Only `x86-64` is built by `windows-build-all.ps1`. To build a single architecture
(`x86-64` or `arm64`, the latter untested) or pass build options, call the
per-architecture script directly:
```
> resources\windows-build.ps1 -JavaHome $env:JAVA_HOME -DepotToolsDir C:\DepotTools `
      -WebRtcDir C:\WebRTC [-Arch x86-64] [-VerboseBuild] [-DebugBuild]
```

The resulting `dcsctp4j.dll` is installed into `src\main\resources\win32-x86-64`,
matching the name JNA's `Platform.RESOURCE_PREFIX` uses to locate it inside the jar.

If the build fails with "No supported Visual Studio can be found", set the
`vs2022_install` (or `vs2019_install`) environment variable to your install path;
WebRTC only checks the default location otherwise.

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
