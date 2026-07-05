# Google Play Data Safety Guide

Google requires you to fill out a Data Safety form in the Play Console. Below are the declarations you must make based on the current CropGuard AI implementation.

## Data Collection and Security

| Question | Answer |
| --- | --- |
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (Firebase handles this) |
| Do you provide a way for users to request that their data be deleted? | **Yes** |

## Data Types Collected

### Personal Information
- **Name**: Collected for account profile. (Collected, Encrypted, Optional)
- **Email Address**: Collected for authentication and account management. (Collected, Encrypted, Mandatory)

### App Information and Performance
- **Crash Logs**: Collected via Firebase Crashlytics to improve the app. (Collected, Encrypted, Mandatory, Analytics)

### Device or Other IDs
- **Device or Other IDs**: FCM tokens for notifications. (Collected, Encrypted, Mandatory, App Functionality)

## Important Note on Images
- **Photos and Videos**: Declare as **Not Collected**.
- Even though the app uses the camera and processes images, they are processed **locally on the device** and not uploaded to a server. Google Play's definition of "collect" refers to data transmitted off the device. If you add community sharing features later where images *are* uploaded, you must update this form.

## Privacy Policy URL
Use the hosted version of `docs/privacy_policy.html`. You can host this for free on GitHub Pages by enabling it for your repository.
