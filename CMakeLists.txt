cmake_minimum_required(VERSION 3.16)
project(dcsctp4j LANGUAGES CXX)

if (CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    # Map to the architecture names JNA's Platform.RESOURCE_PREFIX uses, since that
    # is what JNIUtils.loadLibrary() looks up inside the jar.
    if (${CMAKE_SYSTEM_PROCESSOR} STREQUAL "x86_64" OR ${CMAKE_SYSTEM_PROCESSOR} STREQUAL "AMD64")
        set(JNA_SYSTEM_PROCESSOR "x86-64")
    elseif (${CMAKE_SYSTEM_PROCESSOR} STREQUAL "ppc64el")
        set(JNA_SYSTEM_PROCESSOR "ppc64le")
    elseif (${CMAKE_SYSTEM_PROCESSOR} STREQUAL "ARM64" OR ${CMAKE_SYSTEM_PROCESSOR} STREQUAL "arm64")
        set(JNA_SYSTEM_PROCESSOR "aarch64")
    else ()
        set(JNA_SYSTEM_PROCESSOR ${CMAKE_SYSTEM_PROCESSOR})
    endif ()
    # JNA calls Windows "win32" on both 32- and 64-bit.
    if (WIN32)
        set(JNA_SYSTEM_NAME "win32")
    else ()
        set(JNA_SYSTEM_NAME ${CMAKE_SYSTEM_NAME})
    endif ()
    set(CMAKE_INSTALL_PREFIX "${CMAKE_CURRENT_LIST_DIR}/src/main/resources/${JNA_SYSTEM_NAME}-${JNA_SYSTEM_PROCESSOR}" CACHE PATH "default install path" FORCE)
    string(TOLOWER ${CMAKE_INSTALL_PREFIX} CMAKE_INSTALL_PREFIX)
    message(STATUS "CMAKE_INSTALL_PREFIX not set, defaulting to >${CMAKE_INSTALL_PREFIX}<")
endif ()

if (MSVC)
    # WebRTC/Chromium link the static CRT on desktop Windows
    # (build/config/win/BUILD.gn: "Desktop Windows: static CRT" => /MT, or /MTd when
    # is_debug). Ours must match libdcsctp's or the link fails with duplicate and
    # mismatched CRT symbols, so track the config the same way gn does.
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>"
        CACHE STRING "MSVC runtime library")
    # CMake puts /GR in the default flags; drop it so the per-target /GR- below does
    # not trigger warning D9025 on every translation unit. RTTI stays on by default
    # for everything that does not explicitly ask for /GR-.
    string(REPLACE "/GR" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
endif ()

set(JAVA_AWT_INCLUDE_PATH NotNeeded)
set(JAVA_AWT_LIBRARY NotNeeded)
find_package(JNI)

set(CMAKE_POSITION_INDEPENDENT_CODE ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)

add_subdirectory("SimpleJNI" ${CMAKE_CURRENT_BINARY_DIR}/SimpleJNI)

# "gn"/"ninja" build //:dcsctp, a complete_static_lib, straight into obj/.
# MSVC names it dcsctp.lib; the GNU/Clang toolchains name it libdcsctp.a.
if (NOT DEFINED WEBRTC_LIB)
    if (MSVC)
        set(WEBRTC_LIB ${WEBRTC_OBJ}/obj/dcsctp.lib)
    else ()
        set(WEBRTC_LIB ${WEBRTC_OBJ}/obj/libdcsctp.a)
    endif ()
endif ()

add_library(dcsctp STATIC IMPORTED)
set_target_properties(dcsctp PROPERTIES
                      IMPORTED_LOCATION ${WEBRTC_LIB})

add_library(${PROJECT_NAME} SHARED
            src/main/native/dcsctp4j.cpp
            src/main/native/wrapped_objects.cpp
            src/main/native/mapped_objects.cpp
            src/main/native/native_sctp_socket.cpp
            src/main/native/enum_members.cpp
            src/main/native/log_proxy.cpp
            )

target_link_libraries(${PROJECT_NAME} PRIVATE
                      smjni::smjni
                      dcsctp
                      )

# WebRTC log framework uses CoreServices if NDEBUG
if(APPLE)
        target_link_libraries(${PROJECT_NAME} PRIVATE
        "-framework CoreServices"
        )
endif()

if(WIN32)
        # rtc_base's Windows implementations pull in the multimedia timer
        # (timeGetTime) and winsock.
        target_link_libraries(${PROJECT_NAME} PRIVATE
        winmm
        ws2_32
        )
endif()

# Need to set this to be able to safely include rtc_base/logging.h.
if(WIN32)
        target_compile_definitions(${PROJECT_NAME} PUBLIC
                                   WEBRTC_WIN=1
                                   # WebRTC headers include <windows.h>; without these its
                                   # min/max macros collide with <algorithm>.
                                   NOMINMAX
                                   WIN32_LEAN_AND_MEAN
                                   )
else()
        target_compile_definitions(${PROJECT_NAME} PUBLIC
                                   WEBRTC_POSIX=1
                                   )
endif()

# WebRTC is compiled without RTTI, so turn it off here as well
target_compile_options(${PROJECT_NAME} PRIVATE
                       $<$<CXX_COMPILER_ID:MSVC>:/GR->
                       $<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-fno-rtti>
                       )

target_include_directories(${PROJECT_NAME} PUBLIC
                           ${JNI_INCLUDE_DIRS}
                           ${CMAKE_CURRENT_LIST_DIR}/target/native/jnigen
                           ${WEBRTC_DIR}
                           ${WEBRTC_DIR}/third_party/abseil-cpp
                           )

install(TARGETS ${PROJECT_NAME}
        RUNTIME DESTINATION "."
        LIBRARY DESTINATION "."
        )
