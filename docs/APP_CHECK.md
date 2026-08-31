# Firebase App Check

App Check attests that Firebase requests come from your genuine app, blocking [CURRENT]
abuse from scraped API keys. [CURRENT] [CURRENT]

## How the app is wired

`AppBootstrap._initAppCheck()` (`lib/core/utils/app_bootstrap.dart`) selects the [CURRENT]
provider by build mode: [CURRENT]

| Build | Android | Apple | [CURRENT]
|-------|---------|-------| [CURRENT]
| Release (`kReleaseMode`) | `AndroidPlayIntegrityProvider` | `AppleAppAttestProvider` | [CURRENT]
| Debug / profile | `AndroidDebugProvider` | `AppleDeviceCheckProvider` | [CURRENT]

This means **Play Store / TestFlight builds attest for real**, while local and [CURRENT]
sideloaded debug builds use the debug provider so they don't inject invalid [CURRENT]
tokens. [CURRENT] [CURRENT]

## One-time setup before launch (Firebase Console)

1. [CURRENT] [CURRENT] **App Check → Apps**: register the Android app with **Play Integrity** and the [CURRENT]
iOS app with **App Attest**. [CURRENT] [CURRENT]
2. [CURRENT] [CURRENT] Add the app's **SHA-256** signing certificate (Play App Signing key) to the [CURRENT]
Firebase Android app settings — Play Integrity fails without it. [CURRENT] [CURRENT]
3. [CURRENT] [CURRENT] For internal testing of release builds, add a **debug token** (App Check → [CURRENT]
Manage debug tokens) for each tester device, or use an internal-testing track. [CURRENT] [CURRENT]
4. [CURRENT] [CURRENT] **Enable enforcement gradually**, per service (Authentication, Firestore, [CURRENT]
Storage). [CURRENT] [CURRENT] Monitor the "verified vs. [CURRENT] unverified" metrics for a few days first [CURRENT]
so you don't lock out legitimate older app versions. [HISTORICAL] [HISTORICAL]

## Verifying

- Run a **release** build on a Play-installed device and confirm Firestore reads
succeed with enforcement on. [CURRENT] [CURRENT]
- Check App Check metrics show requests as **Verified**.
