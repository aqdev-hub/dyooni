# Required by vosk_flutter — the plugin talks to Vosk's native library through JNA, and R8/
# ProGuard's default obfuscation would otherwise strip or rename the JNA glue classes it relies
# on at runtime, breaking the native call bridge. See:
# https://github.com/alphacep/vosk-flutter (Installing → Android section).
-keep class com.sun.jna.* { *; }
-keepclassmembers class * extends com.sun.jna.* { public *; }
