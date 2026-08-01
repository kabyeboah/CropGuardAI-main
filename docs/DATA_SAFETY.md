# Google Play Data Safety Guide

Google requires you to fill out a Data Safety form in the Play Console. Below are the declarations you must make based on the current CropGuard AI implementation.

> [!IMPORTANT]
> **Action Required:** This document reflects current app data practices. A human administrator must manually mirror these declarations into the Google Play Console Data Safety form before app release.

## Data Collection and Security

| Question | Answer |
| --- | --- |
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (Firebase & HTTPS) |
| Do you provide a way for users to request that their data be deleted? | **Yes** |

## Data Types Collected

### Personal Information
- **Name**: Collected for account profile. (Collected, Encrypted, Optional)
- **Email Address**: Collected for authentication and account management. (Collected, Encrypted, Mandatory)

### Location
- **Precise / Approximate Location**: Used for crowd-sourced disease outbreak reporting and spatial map visualization. (Collected, Encrypted in transit, Optional/App Functionality)

### Photos and Videos
- **Photos**: Uploaded when submitting community forum posts or outbreak report attachments. (Collected, Encrypted in transit, Optional/App Functionality, tied to user account)

### App Information and Performance
- **Crash Logs**: Collected via Firebase Crashlytics to improve the app. (Collected, Encrypted, Mandatory, Analytics)

### Device or Other IDs
- **Device or Other IDs**: FCM tokens for push notifications. (Collected, Encrypted, Mandatory, App Functionality)

## Privacy Policy URL
Use the hosted version of `docs/privacy_policy.html`. You can host this for free on GitHub Pages by enabling it for your repository.
