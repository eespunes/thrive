# Keep default app rules minimal; add targeted keep rules if obfuscation breaks reflection-based libs.

# --- Sign in with Google via Credential Manager (issue #114) ---
# google_sign_in v7 authenticates through androidx.credentials + the Google
# Identity helper library (com.google.android.libraries.identity.googleid).
# That artifact ships NO consumer keep rules for its own classes, so R8 (which
# is enabled for our release build via isMinifyEnabled/isShrinkResources)
# strips/renames GoogleIdTokenCredential and GetGoogleIdOption. CredentialManager
# relies on those reflectively, so the credential request fails in release-only
# builds and google_sign_in surfaces it as a spurious "Google sign-in cancelled".
# Keeping these classes intact fixes sign-in in minified release builds.
-keep class com.google.android.libraries.identity.googleid.** { *; }
-dontwarn com.google.android.libraries.identity.googleid.**
