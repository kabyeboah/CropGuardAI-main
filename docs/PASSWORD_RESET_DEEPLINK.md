# Password Reset — Open in App (Deep Link)

Goal: when a user taps the reset link in their email, the **app opens directly** [CURRENT]
to an in-app "set new password" screen — not a website. [CURRENT] [CURRENT]

## What's implemented in code

- `SupabaseAuthService.sendPasswordReset` sends the email with redirect URL (`redirectTo: passwordResetContinueUrl`).
- `ResetPasswordScreen` (`/reset_password`) verifies the session/token, takes a new password, and updates the user's password in Supabase Auth.
- `DeepLinkService` (via `app_links`) listens for inbound links and routes authentication redirect tokens to that screen.
- Android `AndroidManifest.xml` has an `autoVerify` App Link intent-filter for `https://cropguardai.app/reset-password`.

## What YOU must configure (cannot be done in code alone)

Deep links only open the app if the OS trusts the domain. Steps:

1. **Pick a domain you control** and replace the placeholders:
   - `AppSecrets.passwordResetContinueUrl`, `androidPackageName`, `iosBundleId`.
   - The `android:host` / `pathPrefix` in `AndroidManifest.xml`.
2. **Supabase Dashboard → Authentication → URL Configuration**:
   - Add your Site URL and Redirect URLs (e.g. `https://cropguardai.app/reset-password`).
3. **Android App Links**: host `https://<domain>/.well-known/assetlinks.json` with the app's package name and the **SHA-256** of your signing key (`keytool -list -v -keystore …`). Then `autoVerify` opens the app directly.
4. **iOS Universal Links**: add an **Associated Domains** entitlement (`applinks:<domain>`) in Xcode and host `https://<domain>/.well-known/apple-app-site-association` for the bundle ID.
5. Add an `ios/Runner/Runner.entitlements` `com.apple.developer.associated-domains` entry.

## Deep Links and Universal Links Architecture

The flow above uses standard Android App Links and iOS Universal Links to your own domain. The link in the password reset email points at your domain with authentication tokens; the OS hands it to the app, and `DeepLinkService` routes it directly to `ResetPasswordScreen`.

## Verify

1. [CURRENT] [CURRENT] Build a release (signed) app on a device. [CURRENT]
2. [CURRENT] [CURRENT] Trigger "forgot password", open the email on the device, tap the link. [CURRENT]
3. [CURRENT] [CURRENT] The app should open `ResetPasswordScreen`; set a new password; confirm you can [CURRENT]
sign in with it. [CURRENT] [CURRENT]
4. [CURRENT] [CURRENT] Android check: `adb shell pm get-app-links <packageName>` should show the [CURRENT]
domain as `verified`. [CURRENT] [CURRENT]
