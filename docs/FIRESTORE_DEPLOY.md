# Firestore security rules

The file [`firestore.rules`](../firestore.rules) in the project root enforces **server-side user scoping**: under `users/{userId}/...`, only `request.auth.uid == userId` may read or write.

## Deploy

1. Install [Firebase CLI](https://firebase.google.com/docs/cli) and run `firebase login`.
2. Link the project: `firebase use <your-project-id>` (or add `.firebaserc`).
3. Deploy rules: `firebase deploy --only firestore:rules`

Alternatively, copy the contents of `firestore.rules` into **Firebase Console → Firestore → Rules** and publish.

## Emulator testing (optional)

Use the Firestore emulator to validate rules before production:

```bash
firebase emulators:start --only firestore
```

Point the Android app at the emulator host (debug build) if you add emulator configuration.
