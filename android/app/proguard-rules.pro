# Flutter embedding and the engine's plugin registry are accessed reflectively.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# package:jni (transitive) loads its Java helpers reflectively from native code.
-keep class com.github.dart_lang.jni.** { *; }

# The engine's deferred-component manager references Play Core classes that are
# only present when using Play Feature Delivery; ZeroBox ships no dynamic
# feature modules, so these references are dead code.
-dontwarn com.google.android.play.core.**
