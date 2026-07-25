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

WebRTC's `gn`/`ninja` build has no support for cross-compiling to Windows from a
non-Windows host, so the Windows build compiles `libdcsctp.a` directly with the
MSVC compiler instead (the same approach the ppc64le build above uses, since `gn`
doesn't support that architecture either). This is done cross-compiling from Linux
using MSVC running under Wine, via [msvc-wine](https://github.com/mstorsjo/msvc-wine).
A real Windows machine isn't required.

Prerequisites:

- OpenJDK 11 (or newer) and Maven, to build the JNI headers and jnigen wrapper
  (a Linux JDK is fine; the Windows build only needs it to run `mvn`/`javac`,
  and it supplies the platform-independent half of `jni.h`)
- CMake
- Git
- APT packages `wine64`, `python3`, `msitools`, `ca-certificates`, `winbind` (these
  are [msvc-wine](https://github.com/mstorsjo/msvc-wine)'s own prerequisites)

* Clone the project
* Update the SimpleJNI subproject with
```
$ git submodule update --init
```
* Build the JNI headers
```
$ mvn compile
```
* Download and unpack MSVC and the Windows SDK with
[msvc-wine](https://github.com/mstorsjo/msvc-wine) (this requires accepting the
Visual Studio license; the toolchain it downloads isn't redistributable, so it
isn't checked into this repository or fetched automatically)
```
$ git clone https://github.com/mstorsjo/msvc-wine
$ msvc-wine/vsdownload.py --accept-license --dest ~/msvc
$ msvc-wine/install.sh ~/msvc
```
* Check out WebRTC and build the libraries (adjusting the paths to DepotTools,
  WebRTC, and the msvc-wine install as desired)
```
$ resources/windows-build-all.sh ~/DepotTools ~/WebRTC ~/msvc
```

> This will automatically check out
[Google DepotTools](https://www.chromium.org/developers/how-tos/install-depot-tools/) and
[WebRTC](https://webrtc.github.io/webrtc-org/native-code/development/); the
latter of these is quite large, so if this is your first checkout make sure
you have enough disk space and be prepared to wait for some time.

> Windows support is newer and less exercised than the Linux and macOS builds; if
you run into build problems, please open an issue.

If you're building directly on a real Windows machine instead of cross-compiling
(e.g. from a Visual Studio Developer Command Prompt / after running `vcvarsall.bat`,
where `cl.exe`/`lib.exe` are already on `PATH`), pass `-` instead of an msvc-wine
directory:
```
$ resources/windows-build.sh <JAVA_HOME> ~/WebRTC/src - x86-64
```
This is how the `windows` job in `.github/workflows/build.yml` builds, on a
`windows-latest` GitHub Actions runner.

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
