const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onUserDeleted } = require("firebase-functions/v2/identity");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Cloud Function: Server-side cascade deletion triggered when a Firebase Auth account is deleted.
 * Purges user Firestore documents, top-level user data, Cloud Storage assets, and scrubs/anonymizes
 * public outbreak reports.
 */
exports.onUserDeleted = onUserDeleted(async (event) => {
  const user = event.data;
  const uid = user.uid;
  console.log(`Starting server-side cascade delete for user account: ${uid}`);

  const db = admin.firestore();
  const bucket = admin.storage().bucket();

  try {
    // 1. Delete user profile document and subcollections recursively
    const userRef = db.collection("users").doc(uid);
    await db.recursiveDelete(userRef);
    console.log(`Deleted /users/${uid} document and all subcollections.`);

    // 2. Cascade delete top-level collections matching userId == uid
    const targetCollections = [
      "scans",
      "treatments",
      "community_posts",
      "feedback",
      "expert_requests",
      "missing_crops",
    ];

    for (const collectionName of targetCollections) {
      const snap = await db.collection(collectionName).where("userId", "==", uid).get();
      if (!snap.empty) {
        const batch = db.batch();
        snap.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
        console.log(`Deleted ${snap.size} records in collection '${collectionName}' for user ${uid}.`);
      }
    }

    // 3. Scrub & anonymize outbreak reports submitted by user (preserve crowd health telemetry)
    const outbreakSnap = await db.collection("outbreak_reports").where("userId", "==", uid).get();
    if (!outbreakSnap.empty) {
      const batch = db.batch();
      outbreakSnap.forEach((doc) => {
        batch.update(doc.ref, {
          userId: "deleted_user",
          reporterName: "Anonymous User",
          notes: admin.firestore.FieldValue.delete(),
          anonymizedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      await batch.commit();
      console.log(`Anonymized ${outbreakSnap.size} outbreak reports for user ${uid}.`);
    }

    // 4. Delete user files from Cloud Storage (scans/{uid} and users/{uid})
    const prefixes = [`scans/${uid}/`, `users/${uid}/`, `profiles/${uid}/`];
    for (const prefix of prefixes) {
      try {
        await bucket.deleteFiles({ prefix: prefix });
        console.log(`Deleted Cloud Storage files under prefix: ${prefix}`);
      } catch (err) {
        console.warn(`Storage deletion under prefix ${prefix} skipped or non-existent:`, err.message);
      }
    }

    console.log(`Successfully completed server-side cascade delete for user ${uid}`);
  } catch (error) {
    console.error(`Error during cascade delete for user ${uid}:`, error);
  }
});

/**
 * Cloud Function: Fan out real-time FCM push notifications when a high-confidence
 * outbreak report is submitted or verified in Firestore.
 */
exports.onOutbreakReportCreatedOrUpdated = onDocumentWritten(
  "outbreak_reports/{reportId}",
  async (event) => {
    const afterData = event.data.after ? event.data.after.data() : null;
    const beforeData = event.data.before ? event.data.before.data() : null;

    if (!afterData) return; // Document deleted

    // Avoid duplicate pushes if notification was already dispatched for this report version
    const verifiedBy = Array.isArray(afterData.verifiedBy) ? afterData.verifiedBy : [];
    const refutedBy = Array.isArray(afterData.refutedBy) ? afterData.refutedBy : [];
    const confidenceScore = afterData.confidenceScore || (1 + verifiedBy.length - refutedBy.length);

    // Trigger push delivery when confidence threshold is met (e.g. verified by 2+ users or high score)
    const isHighConfidence = verifiedBy.length >= 2 || confidenceScore >= 3 || afterData.isHighRisk === true;
    const previouslyNotified = beforeData && beforeData.notifiedAt != null;

    if (!isHighConfidence || (previouslyNotified && beforeData.verifiedBy?.length === verifiedBy.length)) {
      return;
    }

    const diseaseName = afterData.diseaseName || afterData.disease || "Crop Disease";
    const locationName = afterData.locationName || afterData.region || "nearby farm area";
    const reportId = event.params.reportId;

    const topicPayload = {
      notification: {
        title: `🚨 Outbreak Alert: ${diseaseName}`,
        body: `High-confidence ${diseaseName} reported near ${locationName}. Tap to view outbreak map & precautions.`,
      },
      data: {
        type: "outbreak_alert",
        reportId: reportId,
        diseaseName: diseaseName,
        latitude: String(afterData.latitude || afterData.lat || 0),
        longitude: String(afterData.longitude || afterData.lng || 0),
        route: "/outbreak_map",
      },
      topic: "outbreak_alerts",
    };

    try {
      // 1. Send broadcast notification to outbreak_alerts FCM topic (iOS + Android)
      const topicResponse = await admin.messaging().send(topicPayload);
      console.log(`Successfully sent topic push notification for report ${reportId}:`, topicResponse);

      // 2. Query users with active fcmToken for direct targeted fanout
      const usersSnap = await admin.firestore().collection("users")
        .where("fcmToken", "!=", null)
        .limit(500)
        .get();

      const tokens = [];
      usersSnap.forEach((doc) => {
        const token = doc.data().fcmToken;
        if (token && typeof token === "string") {
          tokens.push(token);
        }
      });

      if (tokens.length > 0) {
        const multicastMessage = {
          notification: topicPayload.notification,
          data: topicPayload.data,
          tokens: tokens,
        };
        const batchResponse = await admin.messaging().sendEachForMulticast(multicastMessage);
        console.log(`Multicast FCM delivered to ${batchResponse.successCount}/${tokens.length} devices.`);
      }

      // Mark report document as notified
      await event.data.after.ref.update({
        notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error("Error fanning out FCM push notifications:", error);
    }
  }
);
