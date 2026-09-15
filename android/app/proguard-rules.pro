# Prepared ahead of enabling R8/minification for release builds — NOT yet
# active (`isMinifyEnabled` is currently false in build.gradle.kts, so R8
# never runs and this file is inert). Kept here so that turning minification
# on later is a one-line change instead of a blind guess at keep rules for
# the app's two most reflection-sensitive dependencies: notification
# scheduling (the core reminder pipeline) and Firebase/Firestore model
# (de)serialization. Do not enable isMinifyEnabled without also doing a full
# on-device notification-reliability retest (schedule/fire/boot/actions) —
# see docs/PROJECT_DOCUMENTATION.md's "course corrections" note on not
# touching the notification pipeline without device verification.

# flutter_local_notifications — schedules/receives via reflection-invoked
# broadcast receivers; stripping these silently breaks exact-alarm delivery.
-keep class com.dexterous.** { *; }

# Firebase / Google Play services — model classes are (de)serialized via
# reflection; missing keep rules is a very common cause of release-only
# Firebase crashes that never reproduce in debug.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }
