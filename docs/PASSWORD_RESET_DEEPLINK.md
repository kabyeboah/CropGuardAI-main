# Password Reset — Open in App (Deep Link)

Goal: when a user taps the reset link in their email, the **app opens directly** [CURRENT]
to an in-app "set new password" screen — not a website. [CURRENT] [CURRENT]

## What's implemented in code

- `FirebaseAuthService.sendPasswordReset` sends the email with
`ActionCodeSettings(handleCodeInApp: true, url: passwordResetContinueUrl, …)`. [CURRENT] [CURRENT]
- `FirebaseAuthService.verifyPasswordResetCode` / `confirmPasswordReset` complete
the reset using the `oobCode` from the link. [CURRENT] [CURRENT]
- `ResetPasswordScreen` (`/reset_password?oobCode=…`) verifies the code, takes a
new password, and confirms it — all in-app. [CURRENT] [CURRENT]
- `DeepLinkService` (via `app_links`) listens for inbound links and routes
`…?mode=resetPassword&oobCode=…` (or a `/reset-password` path) to that screen. [CURRENT] [CURRENT]
- Android `AndroidManifest.xml` has an `autoVerify` App Link intent-filter for
`https://cropguardai.app/reset-password`. [CURRENT] [CURRENT]

## What YOU must configure (cannot be done in code alone)

Deep links only open the app if the OS trusts the domain. [CURRENT] [CURRENT] Steps: [CURRENT]

1. [CURRENT] [CURRENT] **Pick a domain you control** and replace the placeholders: [HISTORICAL]
   - `FirebaseAuthService.passwordResetContinueUrl`, `androidPackageName`,
`iosBundleId`. [CURRENT] [CURRENT]
   - The `android:host` / `pathPrefix` in `AndroidManifest.xml`.
2. [CURRENT] [CURRENT] **Firebase Console → Authentication → Settings → Authorized domains**: add the [CURRENT]
domain. [CURRENT] [CURRENT] (Also customise the reset email template if desired.) [CURRENT]
3. [CURRENT] [CURRENT] **Android App Links**: host `https://<domain>/.well-known/assetlinks.json` [CURRENT]
with the app's package name and the **SHA-256** of your signing key [CURRENT]
(`keytool -list -v -keystore …`). [CURRENT] [CURRENT] Then `autoVerify` opens the app directly. [CURRENT]
4. [CURRENT] [CURRENT] **iOS Universal Links**: add an **Associated Domains** entitlement [CURRENT]
(`applinks:<domain>`) in Xcode and host [CURRENT]
`https://<domain>/.well-known/apple-app-site-association` for the bundle ID. [CURRENT] [CURRENT]
5. [CURRENT] [CURRENT] Add an `ios/Runner/Runner.entitlements` `com.apple.developer.associated-domains` [CURRENT]
entry (not added here — needs your domain + provisioning). [CURRENT] [CURRENT]

## Important note on Firebase Dynamic Links

Firebase Dynamic Links is **shut down**. [CURRENT] [CURRENT] The flow above uses standard [CURRENT]
App Links / Universal Links to your own domain (the modern approach). [CURRENT] [CURRENT] The link in [CURRENT]
the email points at your domain with the `oobCode`; the OS hands it to the app, [CURRENT]
and `DeepLinkService` routes it in-app. [CURRENT] [CURRENT] If the domain/verification isn't set up, [CURRENT]
Firebase falls back to its hosted web reset page — so configure the domain to get [CURRENT]
the in-app experience. [CURRENT] [CURRENT]

## Verify

1. [CURRENT] [CURRENT] Build a release (signed) app on a device. [CURRENT]
2. [CURRENT] [CURRENT] Trigger "forgot password", open the email on the device, tap the link. [CURRENT]
3. [CURRENT] [CURRENT] The app should open `ResetPasswordScreen`; set a new password; confirm you can [CURRENT]
sign in with it. [CURRENT] [CURRENT]
4. [CURRENT] [CURRENT] Android check: `adb shell pm get-app-links <packageName>` should show the [CURRENT]
domain as `verified`. [CURRENT] [CURRENT]
