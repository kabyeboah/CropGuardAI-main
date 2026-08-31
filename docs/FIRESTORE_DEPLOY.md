# Firestore security rules

The file [`firestore.rules`](../firestore.rules) in the project root enforces **server-side user scoping**: under `users/{userId}/...`, only `request.auth.uid == userId` may read or write. [CURRENT] [CURRENT]

## Deploy

1. [CURRENT] [CURRENT] Install [Firebase CLI](https://firebase.google.com/docs/cli) and run `firebase login`. [CURRENT]
2. [CURRENT] [CURRENT] Link the project: `firebase use <your-project-id>` (or add `.firebaserc`). [CURRENT]
3. [CURRENT] [CURRENT] Deploy rules: `firebase deploy --only firestore:rules` [CURRENT]

Alternatively, copy the contents of `firestore.rules` into **Firebase Console → Firestore → Rules** and publish. [CURRENT] [CURRENT]

## Emulator testing (optional)

Use the Firestore emulator to validate rules before production: [CURRENT]

```bash
firebase emulators:start --only firestore
```

Point the Android app at the emulator host (debug build) if you add emulator configuration. [CURRENT] [CURRENT]
