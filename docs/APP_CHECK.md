# Firebase App Check

App Check attests that Firebase requests come from your genuine app, blocking
abuse from scraped API keys.

## How the app is wired

`AppBootstrap._initAppCheck()` (`lib/core/utils/app_bootstrap.dart`) selects the
provider by build mode:

| Build | Android | Apple |
|-------|---------|-------|
| Release (`kReleaseMode`) | `AndroidPlayIntegrityProvider` | `AppleAppAttestProvider` |
| Debug / profile | `AndroidDebugProvider` | `AppleDeviceCheckProvider` |

This means **Play Store / TestFlight builds attest for real**, while local and
sideloaded debug builds use the debug provider so they don't inject invalid
tokens.

## One-time setup before launch (Firebase Console)

1. **App Check → Apps**: register the Android app with **Play Integrity** and the
   iOS app with **App Attest**.
2. Add the app's **SHA-256** signing certificate (Play App Signing key) to the
   Firebase Android app settings — Play Integrity fails without it.
3. For internal testing of release builds, add a **debug token** (App Check →
   Manage debug tokens) for each tester device, or use an internal-testing track.
4. **Enable enforcement gradually**, per service (Authentication, Firestore,
   Storage). Monitor the "verified vs. unverified" metrics for a few days first
   so you don't lock out legitimate older app versions.

## Verifying

- Run a **release** build on a Play-installed device and confirm Firestore reads
  succeed with enforcement on.
- Check App Check metrics show requests as **Verified**.
