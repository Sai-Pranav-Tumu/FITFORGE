# FitForge Play Store Data Safety Draft

Last reviewed against this codebase: March 31, 2026

This draft assumes the current app code in this repository, including:

- Firebase Authentication for sign-in
- Google Sign-In
- Cloud Firestore for the FitForge user profile
- Local-only hydration reminders
- Local-only meal history and diet-plan storage
- No Firebase Analytics SDK in the Android app module

## Summary

- Account creation: Yes
- In-app account deletion: Yes
- Public privacy policy required in Play Console: Yes
- External account deletion help page required in Play Console: Yes
- Data shared with third parties for advertising: No
- Data encrypted in transit: Yes
- Users can request deletion: Yes

## Data Safety Answers To Prepare

### Personal info

Collected:

- Name
- Email address
- User IDs

Why:

- App functionality
- Account management
- Security and fraud prevention

Shared:

- No

Processed ephemerally:

- No

Required for app functionality:

- Yes

### Health and fitness

Collected:

- Height
- Weight
- Gender
- Age
- Fitness goal
- Workout frequency
- Workout location
- Equipment availability
- Joint sensitivity
- Dietary preference
- Similar profile fields saved in onboarding/profile

Why:

- App functionality
- Personalization

Shared:

- No

Processed ephemerally:

- No

Required for app functionality:

- Yes, for personalized planning features

## Data Not Currently Collected Remotely

The following data stays on the device in the current implementation and is not sent to your backend:

- Water-tracking history
- Hydration reminder settings
- Saved diet plans
- Local meal history stored in SQLite

If you later sync any of this data to Firestore or another backend, update the Data safety form before release.

## SDK Notes

- Firebase Authentication and Google Sign-In are used
- Cloud Firestore is used
- Firebase Analytics is not included in the Android app module after this change

## Console Items Still Needed Manually

- Upload a public privacy-policy URL that matches `docs/privacy_policy.md`
- Upload a public account-deletion help URL that matches `docs/account_deletion.md`
- Complete the Data safety form using the categories above
- Re-check answers if you add Analytics, Crashlytics, remote meal sync, or any new third-party SDK
