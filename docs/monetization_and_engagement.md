# Monetization & Engagement

This documents the premium/entitlement layer and the reminder/habit system, and
how to take them to production.

## Entitlement (premium gating)

- `lib/services/entitlement_service.dart` — single source of truth for premium
  status. Persists a local flag and mirrors it to Firestore at
  `users/{uid}.isPremium`. Exposed app-wide via `ChangeNotifierProxyProvider`
  in `main.dart`.
- Gate any feature with:
  ```dart
  final isPremium = context.watch<EntitlementService>().isPremium;
  ```
- Currently gated: **progression charts** in the Workout Log screen (free users
  see a blurred teaser + an "Unlock" CTA that opens the paywall).
- Paywall UI: `lib/screens/premium/paywall_screen.dart` (reached from
  Profile → "Go Premium", or from gated features).

### Billing (wired via `in_app_purchase`)

- `lib/services/billing_service.dart` connects to the store, loads subscription
  products, runs the purchase flow, and listens to the purchase stream. On a
  `purchased`/`restored` subscription it grants entitlement via
  `EntitlementService.setPremium(true)` and completes the purchase.
- It calls `restorePurchases()` on init, so premium follows the user to new
  devices via the store (no reliance on the Firestore mirror).
- `PaywallScreen` shows the real product titles/prices and drives the purchase;
  a "Restore purchase" action is included. A clearly-marked **"Unlock (testing)"**
  fallback appears only when no products are configured — remove it before
  production.

**Remaining steps before charging real money:**
1. Create the auto-renewing subscription products in the **Play Console** with IDs
   matching `BillingService.monthlyId` / `yearlyId`
   (`fitforge_premium_monthly`, `fitforge_premium_yearly`). Do the same in App
   Store Connect for iOS.
2. Add a license tester and test the purchase on an internal-testing track.
3. **Verify receipts server-side** in `BillingService._deliver` (a Cloud Function
   checking `purchase.verificationData`) before granting — currently client-side
   only.
4. Once a Cloud Function owns entitlement, switch `firestore.rules` to the
   stricter variant that blocks clients from writing `isPremium`.

### Suggested free vs. premium split

- **Free:** starter pack + full library download, basic plan, set logging,
  basic stats.
- **Premium:** progression charts/analytics, unlimited plan refreshes & diet
  meal swaps, smart reminders, and early access to new features.

## Reminders / habit loop

- `NotificationService` schedules **workout reminders** on selected weekdays at a
  chosen time, plus an optional **evening streak-saver** (`applyWorkoutReminderSettings`).
- Settings UI: Profile → "Workout Reminders" (toggle, time picker, weekday chips,
  streak toggle). Uses inexact alarms, so no `SCHEDULE_EXACT_ALARM` permission is
  needed. `POST_NOTIFICATIONS` is already declared.
- Ideas to extend: tie reminder weekdays to the generated plan's training days,
  add post-workout "log your sets" nudges, and weekly progress recap notifications.

## Analytics already in place

`AnalyticsService` logs `premium_start_tapped`, `set_logged`, `workout_completed`,
`workout_feedback`, and library-download events — use these to measure the
conversion funnel and engagement once live.
