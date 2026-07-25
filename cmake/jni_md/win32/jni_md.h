/*
 * Windows "jni_md.h" (the machine-dependent half of <jni.h>).
 *
 * A Windows JDK ships this next to a platform-independent jni.h under
 * include/win32/. Since the Windows build cross-compiles with a Linux
 * JDK (only used to run javac/mvn and to supply the platform-independent
 * jni.h), that JDK has no win32 subdirectory, so this copy is bundled here
 * and added to the include path ahead of the JDK's own jni_md.h when
 * WIN32 is the target. The content matches upstream OpenJDK, which has
 * been stable across JDK releases.
 */

#ifndef _JAVASOFT_JNI_MD_H_
#define _JAVASOFT_JNI_MD_H_

#define JNIEXPORT __declspec(dllexport)
#define JNIIMPORT __declspec(dllimport)
#define JNICALL __stdcall

typedef int jint;
typedef __int64 jlong;
typedef signed char jbyte;

#endif /* !_JAVASOFT_JNI_MD_H_ */
