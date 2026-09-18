# Required by vosk_flutter — the plugin talks to Vosk's native library through JNA, and R8/
# ProGuard's default obfuscation would otherwise strip or rename the JNA glue classes it relies
# on at runtime, breaking the native call bridge. See:
# https://github.com/alphacep/vosk-flutter (Installing → Android section).
-keep class com.sun.jna.* { *; }
-keepclassmembers class * extends com.sun.jna.* { public *; }

# FIX for the release build failure reported after merging in the other developers' changes:
#   ERROR: Missing classes detected while running R8...
#   ERROR: R8: Missing class java.awt.Component (referenced from: ... com.sun.jna.Native$AWT ...)
#   Missing class java.awt.GraphicsEnvironment / java.awt.HeadlessException / java.awt.Window
#
# Root cause: JNA (a transitive dependency pulled in by vosk_flutter_service) ships an OPTIONAL
# AWT-integration code path inside `Native$AWT` that references `java.awt.*` classes. Those
# classes exist only on a desktop JVM — they are not part of the Android runtime at all, and
# that AWT branch is never actually reached/executed on Android (dead code from Android's
# perspective). R8 still tries to fully resolve every class referenced anywhere in the compiled
# bytecode of every dependency, even ones this app never calls, and refuses to finish the build
# unless told explicitly that these references are expected to be absent and safe to ignore.
#
# `-dontwarn` (NOT `-keep`) is the correct fix here: keeping java.awt.* would be wrong since
# those classes genuinely don't exist on Android and were never meant to run there — dontwarn
# just tells R8 "these missing references are known and fine, don't fail the build over them."
-dontwarn java.awt.**
-dontwarn com.sun.jna.**
