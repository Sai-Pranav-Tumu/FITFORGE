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

### Server-side verification (done — Cloud Functions)

- `functions/index.js` contains:
  - **`verifyPlayPurchase`** (callable): the app sends `{ productId, purchaseToken }`
    after a purchase; the function verifies it against the Google Play Developer
    API (`purchases.subscriptionsv2.get`), acknowledges it, and writes the
    authoritative `isPremium` to `users/{uid}` only if the subscription is active.
  - **`handlePlayRtdn`** (Pub/Sub): consumes Real-time Developer Notifications to
    keep `isPremium` in sync on renewals / cancellations / refunds.
- `BillingService._deliver` calls `verifyPlayPurchase` and applies the verified
  result via `EntitlementService.applyVerifiedEntitlement` (no client Firestore
  write). If the function is unreachable it falls back to a local-only grant so a
  paying user isn't blocked; the server reconciles on the next restore/RTDN.
- **`firestore.rules` is locked down**: clients can read their own data and update
  their profile, but **cannot write `isPremium`** — only the Cloud Functions can.

### Payment methods (UPI / cards)

Google Play **requires** digital subscriptions to use Play Billing, so we do not
use a separate UPI/card gateway (that would violate policy and risk removal).
Play Billing already presents **UPI, cards, net banking and wallets** at checkout
in India — the user picks one in the Google Play sheet. The paywall communicates
this ("Secure payment via Google Play · UPI · Cards · Net banking · Wallets").

### Deploy checklist before charging real money

1. Create the auto-renewing subscription products in the **Play Console** with IDs
   matching `BillingService.monthlyId` / `yearlyId`
   (`fitforge_premium_monthly`, `fitforge_premium_yearly`).
2. Play Console → Setup → API access: link a **service account** with
   "View financial data" + "Manage orders", and grant the functions runtime the
   same identity so ADC can call the Android Publisher API.
3. `cd functions && npm install`, then `firebase deploy --only functions,firestore:rules`.
4. (Optional but recommended) Create a Pub/Sub topic `play-subscription-notifications`
   and set it in Play Console → Monetization setup → RTDN.
5. Add license testers and test the full purchase on an internal-testing track
   (UPI/card both work in test).
6. Remove the dev-only **"Unlock (testing)"** button in `paywall_screen.dart`.

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
