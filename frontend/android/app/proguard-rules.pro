# Keep MediaPipe and its internal logging dependencies from being stripped
-keep class com.google.mediapipe.** { *; }
-keep class com.google.common.flogger.** { *; }
-dontwarn com.google.common.flogger.**