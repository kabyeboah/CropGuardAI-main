# Password Reset — Open in App (Deep Link)

Goal: when a user taps the reset link in their email, the **app opens directly**
to an in-app "set new password" screen — not a website.

## What's implemented in code

- `FirebaseAuthService.sendPasswordReset` sends the email with
  `ActionCodeSettings(handleCodeInApp: true, url: passwordResetContinueUrl, …)`.
- `FirebaseAuthService.verifyPasswordResetCode` / `confirmPasswordReset` complete
  the reset using the `oobCode` from the link.
- `ResetPasswordScreen` (`/reset_password?oobCode=…`) verifies the code, takes a
  new password, and confirms it — all in-app.
- `DeepLinkService` (via `app_links`) listens for inbound links and routes
  `…?mode=resetPassword&oobCode=…` (or a `/reset-password` path) to that screen.
- Android `AndroidManifest.xml` has an `autoVerify` App Link intent-filter for
  `https://cropguardai.app/reset-password`.

## What YOU must configure (cannot be done in code alone)

Deep links only open the app if the OS trusts the domain. Steps:

1. **Pick a domain you control** and replace the placeholders:
   - `FirebaseAuthService.passwordResetContinueUrl`, `androidPackageName`,
     `iosBundleId`.
   - The `android:host` / `pathPrefix` in `AndroidManifest.xml`.
2. **Firebase Console → Authentication → Settings → Authorized domains**: add the
   domain. (Also customise the reset email template if desired.)
3. **Android App Links**: host `https://<domain>/.well-known/assetlinks.json`
   with the app's package name and the **SHA-256** of your signing key
   (`keytool -list -v -keystore …`). Then `autoVerify` opens the app directly.
4. **iOS Universal Links**: add an **Associated Domains** entitlement
   (`applinks:<domain>`) in Xcode and host
   `https://<domain>/.well-known/apple-app-site-association` for the bundle ID.
5. Add an `ios/Runner/Runner.entitlements` `com.apple.developer.associated-domains`
   entry (not added here — needs your domain + provisioning).

## Important note on Firebase Dynamic Links

Firebase Dynamic Links is **shut down**. The flow above uses standard
App Links / Universal Links to your own domain (the modern approach). The link in
the email points at your domain with the `oobCode`; the OS hands it to the app,
and `DeepLinkService` routes it in-app. If the domain/verification isn't set up,
Firebase falls back to its hosted web reset page — so configure the domain to get
the in-app experience.

## Verify

1. Build a release (signed) app on a device.
2. Trigger "forgot password", open the email on the device, tap the link.
3. The app should open `ResetPasswordScreen`; set a new password; confirm you can
   sign in with it.
4. Android check: `adb shell pm get-app-links <packageName>` should show the
   domain as `verified`.
