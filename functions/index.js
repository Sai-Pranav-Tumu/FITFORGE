/**
 * FitForge Cloud Functions — Google Play purchase verification.
 *
 * - `verifyPlayPurchase` (callable): the app sends a productId + purchaseToken
 *   after a purchase. We verify it against the Google Play Developer API and,
 *   only if the subscription is genuinely active, write `isPremium: true` to the
 *   user's Firestore doc. Clients can NOT write `isPremium` themselves (see
 *   firestore.rules), so entitlement is tamper-proof.
 * - `handlePlayRtdn` (Pub/Sub): receives Real-time Developer Notifications for
 *   renewals / cancellations / refunds and keeps `isPremium` in sync over time.
 *
 * Setup:
 *   1. `cd functions && npm install`
 *   2. In the Play Console → Setup → API access, link a service account and grant
 *      it "View financial data" + "Manage orders". Give that same service account
 *      the runtime role on the function (or set it as the functions runtime SA) so
 *      Application Default Credentials can call the Android Publisher API.
 *   3. (For RTDN) Create a Pub/Sub topic `play-subscription-notifications` and set
 *      it in Play Console → Monetization setup → Real-time developer notifications.
 *   4. `firebase deploy --only functions`
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onMessagePublished } = require("firebase-functions/v2/pubsub");
const { setGlobalOptions } = require("firebase-functions/v2");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { google } = require("googleapis");

admin.initializeApp();
const db = admin.firestore();

setGlobalOptions({ region: "us-central1", maxInstances: 10 });

// Must match android/app `applicationId`.
const PACKAGE_NAME = "com.fitforge.app";
const RTDN_TOPIC = "play-subscription-notifications";

const androidPublisher = google.androidpublisher({
  version: "v3",
  auth: new google.auth.GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  }),
});

function isActiveState(state) {
  return (
    state === "SUBSCRIPTION_STATE_ACTIVE" ||
    state === "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"
  );
}

function latestExpiryMillis(subscription) {
  const lineItems = subscription.lineItems || [];
  let latest = 0;
  for (const item of lineItems) {
    if (item.expiryTime) {
      const parsed = Date.parse(item.expiryTime);
      if (!Number.isNaN(parsed) && parsed > latest) latest = parsed;
    }
  }
  return latest;
}

async function fetchSubscription(purchaseToken) {
  const res = await androidPublisher.purchases.subscriptionsv2.get({
    packageName: PACKAGE_NAME,
    token: purchaseToken,
  });
  return res.data;
}

async function acknowledgeIfNeeded(subscription, productId, purchaseToken) {
  if (subscription.acknowledgementState !== "ACKNOWLEDGEMENT_STATE_PENDING") {
    return;
  }
  try {
    await androidPublisher.purchases.subscriptions.acknowledge({
      packageName: PACKAGE_NAME,
      subscriptionId: productId,
      token: purchaseToken,
      requestBody: {},
    });
  } catch (err) {
    logger.warn("Acknowledge failed", err);
  }
}

// Maps a Play product id to the subscription tier it grants.
function tierForProduct(productId) {
  const p = String(productId || "").toLowerCase();
  if (p.startsWith("max")) return "max";
  if (p.startsWith("pro")) return "pro";
  // Legacy single-premium products map to Pro.
  if (p.includes("premium")) return "pro";
  return "free";
}

async function writeEntitlement(uid, productId, purchaseToken, subscription) {
  const active = isActiveState(subscription.subscriptionState);
  const expiryMillis = latestExpiryMillis(subscription);
  const now = admin.firestore.FieldValue.serverTimestamp();
  const tier = active ? tierForProduct(productId) : "free";

  // token -> uid map so RTDN can resolve the user later.
  await db.collection("subscriptions").doc(purchaseToken).set(
    {
      uid,
      productId,
      subscriptionState: subscription.subscriptionState || null,
      expiryMillis,
      updatedAt: now,
    },
    { merge: true }
  );

  await db.collection("users").doc(uid).set(
    {
      isPremium: active,
      tier,
      premium: {
        productId,
        purchaseToken,
        subscriptionState: subscription.subscriptionState || null,
        expiryMillis,
        updatedAt: now,
      },
    },
    { merge: true }
  );

  return { active, expiryMillis, tier };
}

exports.verifyPlayPurchase = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  const productId = request.data && request.data.productId;
  const purchaseToken = request.data && request.data.purchaseToken;
  if (!productId || !purchaseToken) {
    throw new HttpsError(
      "invalid-argument",
      "productId and purchaseToken are required."
    );
  }

  let subscription;
  try {
    subscription = await fetchSubscription(purchaseToken);
  } catch (err) {
    logger.error("Play verification failed", err);
    throw new HttpsError("internal", "Could not verify the purchase.");
  }

  await acknowledgeIfNeeded(subscription, productId, purchaseToken);
  const { active, expiryMillis, tier } = await writeEntitlement(
    uid,
    productId,
    purchaseToken,
    subscription
  );

  return { isPremium: active, tier, expiryMillis };
});

exports.handlePlayRtdn = onMessagePublished(RTDN_TOPIC, async (event) => {
  const message = event.data && event.data.message;
  if (!message || !message.data) return;

  let payload;
  try {
    payload = JSON.parse(Buffer.from(message.data, "base64").toString("utf8"));
  } catch (err) {
    logger.error("Bad RTDN payload", err);
    return;
  }

  const notification = payload.subscriptionNotification;
  if (!notification || !notification.purchaseToken) return;
  const purchaseToken = notification.purchaseToken;

  const mapping = await db.collection("subscriptions").doc(purchaseToken).get();
  if (!mapping.exists) {
    logger.warn("RTDN: no uid mapping for token", purchaseToken);
    return;
  }
  const { uid, productId } = mapping.data();

  let subscription;
  try {
    subscription = await fetchSubscription(purchaseToken);
  } catch (err) {
    logger.error("RTDN re-verification failed", err);
    return;
  }

  await writeEntitlement(uid, productId, purchaseToken, subscription);
});
