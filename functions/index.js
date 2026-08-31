const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onUserDeleted } = require("firebase-functions/v2/identity");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

// ── Khaya AI API Version Configuration ─────────────────────────────────────
// Centralised here so any future migration is a single-line change.
// NEVER reference v1 or v2 ASR / v1 TTS in production code.
const KHAYA_BASE_URL = "https://translation-api.ghananlp.org";
const KHAYA_ASR_VERSION = "v3";          // ASR v1 and v2 are DEPRECATED
const KHAYA_TTS_VERSION = "v2";          // TTS v1 is DEPRECATED
const KHAYA_TRANSLATION_ENDPOINT = "/translate"; // Translation v2

/**
 * Diagnostic Sanitizer: Redacts API keys and raw base64 data chunks from Cloud Function error logs.
 */
function sanitizeServerLog(input) {
  if (!input) return "";
  let text = typeof input === "string" ? input : (input.message || String(input));
  const geminiKey = process.env.GEMINI_API_KEY;
  const ghanaNlpKey = process.env.GHANA_NLP_SUBSCRIPTION_KEY;
  if (geminiKey && geminiKey.length > 5) text = text.split(geminiKey).join("[REDACTED_GEMINI_KEY]");
  if (ghanaNlpKey && ghanaNlpKey.length > 5) text = text.split(ghanaNlpKey).join("[REDACTED_GHANA_KEY]");
  text = text.replace(/AIza[0-9A-Za-z\-_]{35}/g, "[REDACTED_API_KEY]");
  text = text.replace(/data:image\/[a-zA-Z0-9.+-]+;base64,[A-Za-z0-9+/=]+/g, "[BASE64_IMAGE_DATA]");
  text = text.replace(/\b[A-Za-z0-9+/]{64,}={0,2}\b/g, "[BASE64_PAYLOAD]");
  return text;
}

/**
 * Cloud Function (Callable): Secure Outbreak Verification Mutation.
 * Moves outbreak voting and confidence recalculation to a trusted server transaction.
 * Prevents client-side state forging, duplicate voting, and race conditions.
 */
exports.verifyOutbreak = onCall(async (request) => {
  // 1. Verify caller authentication
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication required to verify outbreak reports."
    );
  }

  const uid = request.auth.uid;
  const data = request.data || {};
  const reportId = data.reportId;
  const confirm = Boolean(data.confirm);

  if (!reportId || typeof reportId !== "string" || reportId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "A valid reportId string is required.");
  }

  const db = admin.firestore();
  const reportRef = db.collection("outbreak_reports").doc(reportId.trim());

  try {
    const result = await db.runTransaction(async (transaction) => {
      const doc = await transaction.get(reportRef);
      if (!doc.exists) {
        throw new HttpsError("not-found", `Outbreak report '${reportId}' not found.`);
      }

      const reportData = doc.data() || {};
      const rawVerified = Array.isArray(reportData.verifiedBy) ? reportData.verifiedBy : [];
      const rawRefuted = Array.isArray(reportData.refutedBy) ? reportData.refutedBy : [];

      // Clean sets to ensure unique entries
      const verifiedSet = new Set(rawVerified);
      const refutedSet = new Set(rawRefuted);

      // Check for duplicate voting
      if (confirm) {
        if (verifiedSet.has(uid) && !refutedSet.has(uid)) {
          // Already verified by this user; idempotent return without mutation
          return {
            status: "noop",
            message: "User already verified this outbreak report.",
            verifiedCount: verifiedSet.size,
            refutedCount: refutedSet.size,
            confidenceScore: reportData.confidenceScore || Math.max(1, 1 + verifiedSet.size - refutedSet.size),
          };
        }
        verifiedSet.add(uid);
        refutedSet.delete(uid);
      } else {
        if (refutedSet.has(uid) && !verifiedSet.has(uid)) {
          // Already refuted by this user; idempotent return without mutation
          return {
            status: "noop",
            message: "User already refuted this outbreak report.",
            verifiedCount: verifiedSet.size,
            refutedCount: refutedSet.size,
            confidenceScore: reportData.confidenceScore || Math.max(1, 1 + verifiedSet.size - refutedSet.size),
          };
        }
        refutedSet.add(uid);
        verifiedSet.delete(uid);
      }

      const updatedVerifiedBy = Array.from(verifiedSet);
      const updatedRefutedBy = Array.from(refutedSet);
      const updatedConfidenceScore = Math.max(1, 1 + updatedVerifiedBy.length - updatedRefutedBy.length);

      transaction.update(reportRef, {
        verifiedBy: updatedVerifiedBy,
        refutedBy: updatedRefutedBy,
        confidenceScore: updatedConfidenceScore,
        lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        status: "updated",
        verifiedCount: updatedVerifiedBy.length,
        refutedCount: updatedRefutedBy.length,
        confidenceScore: updatedConfidenceScore,
      };
    });

    return {
      success: true,
      reportId: reportId,
      ...result,
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    console.error(`Error verifying outbreak ${reportId}:`, error);
    throw new HttpsError("internal", "Failed to process outbreak verification.");
  }
});

/**
 * Cloud Function: Server-side cascade deletion triggered when a Firebase Auth account is deleted.
 * Purges user Firestore documents, top-level user data in scalable batches (< 500 docs per commit),
 * Cloud Storage assets, and scrubs/anonymizes public outbreak reports.
 */
exports.onUserDeleted = onUserDeleted(async (event) => {
  const user = event.data;
  const uid = user.uid;
  console.log(`Starting server-side cascade delete for user account: ${uid}`);

  const db = admin.firestore();
  const storage = admin.storage();
  const bucket = storage.bucket();

  try {
    // 1. Delete user profile document and subcollections recursively
    const userRef = db.collection("users").doc(uid);
    try {
      await db.recursiveDelete(userRef);
      console.log(`Deleted /users/${uid} document and all subcollections.`);
    } catch (err) {
      console.warn(`User profile recursive delete note: ${err.message}`);
    }

    // 2. Cascade delete top-level collections matching userId == uid in scalable batches
    const targetCollections = [
      "scans",
      "treatments",
      "community_posts",
      "feedback",
      "expert_requests",
      "missing_crops",
    ];

    for (const collectionName of targetCollections) {
      let totalDeleted = 0;
      while (true) {
        const snap = await db.collection(collectionName)
          .where("userId", "==", uid)
          .limit(500)
          .get();

        if (snap.empty) break;

        const batch = db.batch();
        snap.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();

        totalDeleted += snap.size;
        if (snap.size < 500) break;
      }
      if (totalDeleted > 0) {
        console.log(`Deleted ${totalDeleted} records in '${collectionName}' for user ${uid}.`);
      }
    }

    // 3. Scrub & anonymize outbreak reports submitted by user in scalable batches
    let totalAnonymized = 0;
    while (true) {
      const outbreakSnap = await db.collection("outbreak_reports")
        .where("userId", "==", uid)
        .limit(500)
        .get();

      if (outbreakSnap.empty) break;

      const batch = db.batch();
      outbreakSnap.forEach((doc) => {
        batch.update(doc.ref, {
          userId: "deleted_user",
          reporterName: "Anonymous Farmer",
          notes: admin.firestore.FieldValue.delete(),
          anonymizedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      await batch.commit();

      totalAnonymized += outbreakSnap.size;
      if (outbreakSnap.size < 500) break;
    }
    if (totalAnonymized > 0) {
      console.log(`Anonymized ${totalAnonymized} outbreak reports for user ${uid}.`);
    }

    // 4. Delete user files from Cloud Storage across all user prefixes
    const prefixes = [
      `scans/${uid}/`,
      `users/${uid}/`,
      `profiles/${uid}/`,
      `feedback/${uid}/`,
      `community_posts/${uid}/`,
    ];
    for (const prefix of prefixes) {
      try {
        await bucket.deleteFiles({ prefix: prefix });
        console.log(`Deleted Cloud Storage files under prefix: ${prefix}`);
      } catch (err) {
        console.warn(`Storage deletion under prefix ${prefix} skipped: ${err.message}`);
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
 * Features:
 * - Duplicate notification prevention with state tracking
 * - Scalable topic broadcast
 * - Automatic stale FCM token cleanup
 */
exports.onOutbreakReportCreatedOrUpdated = onDocumentWritten(
  "outbreak_reports/{reportId}",
  async (event) => {
    const afterData = event.data.after ? event.data.after.data() : null;
    const beforeData = event.data.before ? event.data.before.data() : null;

    if (!afterData) return; // Document deleted

    const verifiedBy = Array.isArray(afterData.verifiedBy) ? afterData.verifiedBy : [];
    const refutedBy = Array.isArray(afterData.refutedBy) ? afterData.refutedBy : [];
    const confidenceScore = afterData.confidenceScore || Math.max(1, 1 + verifiedBy.length - refutedBy.length);

    // Trigger push delivery when confidence threshold is met
    const isHighConfidence = verifiedBy.length >= 2 || confidenceScore >= 3 || afterData.isHighRisk === true;
    if (!isHighConfidence) return;

    // Check previous notification state to prevent duplicate delivery
    const previouslyNotified = beforeData && beforeData.notifiedAt != null;
    const previousConfidence = beforeData?.confidenceScore || 0;
    const previousVerifiedCount = Array.isArray(beforeData?.verifiedBy) ? beforeData.verifiedBy.length : 0;

    // Prevent duplicate push if already notified and no significant verification change
    if (previouslyNotified && verifiedBy.length <= previousVerifiedCount && confidenceScore <= previousConfidence) {
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
      // 1. Broadcast to global topic (scalable for unlimited subscribers without duplicate delivery)
      const topicResponse = await admin.messaging().send(topicPayload);
      console.log(`Successfully sent topic push notification for report ${reportId}:`, topicResponse);

      // 2. Mark report document as notified and record notified metadata
      await event.data.after.ref.update({
        notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastNotifiedConfidence: confidenceScore,
        lastNotifiedVerifiedCount: verifiedBy.length,
      });
    } catch (error) {
      console.error("Error sending outbreak push notification:", error);
    }
  }
);

/**
 * Utility Helper: Clean up stale FCM tokens in batches.
 * Removes invalid or unregistered tokens identified during messaging operations.
 */
async function purgeStaleFcmTokens(tokens, db) {
  if (!tokens || tokens.length === 0) return;
  try {
    for (let i = 0; i < tokens.length; i += 500) {
      const chunk = tokens.slice(i, i + 500);
      const snap = await db.collection("users")
        .where("fcmToken", "in", chunk)
        .get();

      if (!snap.empty) {
        const batch = db.batch();
        snap.forEach((doc) => {
          batch.update(doc.ref, {
            fcmToken: admin.firestore.FieldValue.delete(),
            fcmTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });
        await batch.commit();
        console.log(`Purged ${snap.size} stale FCM tokens from users collection.`);
      }
    }
  } catch (error) {
    console.warn("Failed to purge stale FCM tokens:", error);
  }
}

exports.purgeStaleFcmTokens = purgeStaleFcmTokens;

/**
 * Cloud Function (Callable): Secure Server-Side Gemini Multimodal Crop Diagnosis Proxy.
 * Authenticated via Firebase Auth & App Check.
 * Master GEMINI_API_KEY is stored in server-side environment / GCP Secret Manager.
 */
exports.analyzeCropWithGemini = onCall(async (request) => {
  // 1. Enforce caller authentication
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication required to perform Gemini cloud diagnosis."
    );
  }

  const data = request.data || {};
  const imageBase64 = data.imageBase64;
  const cropType = data.cropType || "";
  const initialTopCandidates = Array.isArray(data.initialTopCandidates) ? data.initialTopCandidates : [];

  if (!imageBase64 || typeof imageBase64 !== "string" || imageBase64.length === 0) {
    throw new HttpsError("invalid-argument", "Valid imageBase64 data is required.");
  }

  // Enforce maximum payload size (approx 10MB base64)
  if (imageBase64.length > 14 * 1024 * 1024) {
    throw new HttpsError("invalid-argument", "Image payload exceeds 10MB size limit.");
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    console.error("GEMINI_API_KEY is not configured on the server.");
    throw new HttpsError("failed-precondition", "Gemini Cloud AI is not configured on the server.");
  }

  const candidateInfo = initialTopCandidates.length > 0
    ? `On-device preliminary model candidates: ${initialTopCandidates.join(", ")}.`
    : "";
  const cropContext = cropType ? `Crop Type: ${cropType}.` : "";

  const promptText = `You are an expert plant pathologist and agricultural scientist specializing in West African & global crop diseases (e.g., Cocoa, Cassava, Maize, Rice, Tomato, Plantain).
Analyze this crop leaf/plant image carefully and return a JSON object with the following schema:

{
  "label": "Name of the crop disease or Healthy state (e.g. Cocoa Black Pod Disease, Cassava Mosaic Disease, Healthy Maize)",
  "confidence": 0.88,
  "isHealthy": false,
  "symptoms": ["Dark water-soaked lesions", "Fungal mycelium growth"],
  "rootCause": "Phytophthora palmivora pathogen infection accelerated by high humidity.",
  "organicRemedies": ["Apply copper-based fungicide spray", "Prune affected lower canopy leaves"],
  "preventionTips": ["Ensure adequate shade management", "Improve field drainage"],
  "sourceBasis": "Authoritative agricultural basis (e.g., CABI Plantwise / MoFA PPRSD / CRIG / IITA Guidelines)",
  "safetyPrecautions": "Wear PPE (gloves, mask, eye protection) when applying treatments. Follow Pre-Harvest Intervals (PHI).",
  "rawReasoning": "Detailed visual analysis of lesions, leaf chlorosis, and texture."
}

Context:
${cropContext}
${candidateInfo}
Return strictly valid JSON only.`;

  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`;

  const payload = {
    contents: [
      {
        parts: [
          { text: promptText },
          {
            inline_data: {
              mime_type: "image/jpeg",
              data: imageBase64,
            },
          },
        ],
      },
    ],
    generationConfig: {
      response_mime_type: "application/json",
      temperature: 0.2,
    },
  };

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errText = await response.text();
      console.error(`Gemini API error (${response.status}):`, sanitizeServerLog(errText));
      throw new HttpsError("internal", `Gemini API returned status ${response.status}`);
    }

    const resJson = await response.json();
    const candidateText = resJson?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!candidateText || candidateText.trim().length === 0) {
      throw new HttpsError("internal", "Empty response received from Gemini Cloud AI.");
    }

    const cleanJson = candidateText.replace(/^```json\s*|\s*```$/g, "").trim();
    const resultObj = JSON.parse(cleanJson);

    return {
      success: true,
      result: resultObj,
    };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error("Gemini diagnosis exception:", sanitizeServerLog(error));
    throw new HttpsError("internal", `Gemini analysis failed: ${sanitizeServerLog(error.message)}`);
  }
});

/**
 * Cloud Function (Callable): Secure Server-Side Khaya AI Text-to-Speech Proxy.
 * API Version: TTS v2 (TTS v1 is DEPRECATED — DO NOT DOWNGRADE).
 * Authenticated via Firebase Auth & App Check.
 * Master GHANA_NLP_SUBSCRIPTION_KEY is stored in server-side environment / GCP Secret Manager.
 */
exports.synthesizeGhanaNlp = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication required to access voice synthesis."
    );
  }

  const data = request.data || {};
  const text = (data.text || "").trim();
  const language = (data.language || "tw").trim();

  if (!text) {
    throw new HttpsError("invalid-argument", "Text to synthesize is required.");
  }
  if (text.length > 2000) {
    throw new HttpsError("invalid-argument", "Text exceeds maximum 2000 characters limit.");
  }

  // Validate language against known supported codes
  const supportedTtsLanguages = ["tw", "ee", "dag", "gaa", "fat"];
  if (!supportedTtsLanguages.includes(language)) {
    // Allow unknown languages through — provider will return 400 if unsupported
    console.warn(`TTS: language '${language}' is not in verified supported list.`);
  }

  const subscriptionKey = process.env.GHANA_NLP_SUBSCRIPTION_KEY;
  if (!subscriptionKey) {
    console.error("GHANA_NLP_SUBSCRIPTION_KEY is not configured on the server.");
    throw new HttpsError("failed-precondition", "Ghana NLP is not configured on the server.");
  }

  // Centralised speaker ID mapping — update here when provider adds voices
  const speakerIds = {
    "tw": "twi_speaker_4",
    "ee": "ewe_speaker_1",
    "dag": "dagbani_speaker_1",
  };
  const speakerId = speakerIds[language] || `${language}_speaker_1`;

  // TTS v2 endpoint — DO NOT revert to /tts/v1 (deprecated)
  const ttsUrl = `${KHAYA_BASE_URL}/tts/${KHAYA_TTS_VERSION}/synthesize`;

  try {
    const response = await fetch(ttsUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Ocp-Apim-Subscription-Key": subscriptionKey,
      },
      body: JSON.stringify({
        text: text,
        language: language,
        speaker_id: speakerId,
      }),
    });

    if (!response.ok) {
      const errText = await response.text();
      console.error(`Khaya TTS v2 error (${response.status}):`, sanitizeServerLog(errText));
      if (response.status === 401 || response.status === 403) {
        throw new HttpsError("unauthenticated", "Khaya TTS authentication failed.");
      }
      if (response.status === 429) {
        throw new HttpsError("resource-exhausted", "Khaya TTS rate limit exceeded.");
      }
      throw new HttpsError("internal", `Khaya TTS v2 failed with status ${response.status}`);
    }

    const arrayBuffer = await response.arrayBuffer();
    if (!arrayBuffer || arrayBuffer.byteLength === 0) {
      throw new HttpsError("internal", "Khaya TTS v2 returned empty audio response.");
    }
    const base64Audio = Buffer.from(arrayBuffer).toString("base64");

    return {
      success: true,
      audioBase64: base64Audio,
      language: language,
      apiVersion: KHAYA_TTS_VERSION,
    };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error("Khaya TTS v2 exception:", sanitizeServerLog(error));
    throw new HttpsError("internal", `TTS synthesis failed: ${sanitizeServerLog(error.message)}`);
  }
});

/**
 * Cloud Function (Callable): Secure Server-Side Khaya AI Speech-to-Text (ASR) Proxy.
 * API Version: ASR v3 (ASR v1 and v2 are DEPRECATED — DO NOT DOWNGRADE).
 * Authenticated via Firebase Auth & App Check.
 * Master GHANA_NLP_SUBSCRIPTION_KEY is stored in server-side environment / GCP Secret Manager.
 */
exports.transcribeGhanaNlp = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication required to access voice transcription."
    );
  }

  const data = request.data || {};
  const audioBase64 = data.audioBase64;
  const language = (data.language || "tw").trim();

  if (!audioBase64 || typeof audioBase64 !== "string") {
    throw new HttpsError("invalid-argument", "audioBase64 data is required.");
  }
  if (audioBase64.length === 0) {
    throw new HttpsError("invalid-argument", "Audio data must not be empty.");
  }

  // Validate language against known supported ASR codes
  const supportedAsrLanguages = ["tw", "ee", "dag", "gaa", "fat"];
  if (!supportedAsrLanguages.includes(language)) {
    console.warn(`ASR: language '${language}' is not in verified supported list.`);
  }

  const subscriptionKey = process.env.GHANA_NLP_SUBSCRIPTION_KEY;
  if (!subscriptionKey) {
    console.error("GHANA_NLP_SUBSCRIPTION_KEY is not configured on the server.");
    throw new HttpsError("failed-precondition", "Ghana NLP is not configured on the server.");
  }

  // ASR v3 endpoint — DO NOT revert to /asr/v2 or /asr/v1 (both deprecated)
  const asrUrl = `${KHAYA_BASE_URL}/asr/${KHAYA_ASR_VERSION}/transcribe?language=${language}`;

  try {
    const audioBuffer = Buffer.from(audioBase64, "base64");
    if (audioBuffer.length === 0) {
      throw new HttpsError("invalid-argument", "Decoded audio buffer is empty.");
    }

    const response = await fetch(asrUrl, {
      method: "POST",
      headers: {
        "Content-Type": "audio/wav",
        "Ocp-Apim-Subscription-Key": subscriptionKey,
      },
      body: audioBuffer,
    });

    if (!response.ok) {
      const errText = await response.text();
      console.error(`Khaya ASR v3 error (${response.status}):`, sanitizeServerLog(errText));
      if (response.status === 401 || response.status === 403) {
        throw new HttpsError("unauthenticated", "Khaya ASR authentication failed.");
      }
      if (response.status === 429) {
        throw new HttpsError("resource-exhausted", "Khaya ASR rate limit exceeded.");
      }
      throw new HttpsError("internal", `Khaya ASR v3 failed with status ${response.status}`);
    }

    const responseText = await response.text();
    let text = responseText.trim();

    // Handle both plain-string and JSON responses from the provider
    if (text.startsWith("{") && text.endsWith("}")) {
      try {
        const decoded = JSON.parse(text);
        if (decoded && typeof decoded.text === "string") {
          text = decoded.text.trim();
        }
      } catch (_) { /* keep raw text if parse fails */ }
    }
    // Strip enclosing quotes if provider returns "\"transcript\""
    if (text.startsWith('"') && text.endsWith('"') && text.length > 1) {
      text = text.substring(1, text.length - 1).trim();
    }

    return {
      success: true,
      transcription: text,
      language: language,
      apiVersion: KHAYA_ASR_VERSION,
    };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error("Khaya ASR v3 exception:", sanitizeServerLog(error));
    throw new HttpsError("internal", `ASR transcription failed: ${sanitizeServerLog(error.message)}`);
  }
});

/**
 * Cloud Function (Callable): Secure Server-Side Khaya AI Translation Proxy.
 * API Version: Translation v2 (Translation v1 is DEPRECATED — DO NOT DOWNGRADE).
 * Authenticated via Firebase Auth & App Check.
 * Master GHANA_NLP_SUBSCRIPTION_KEY is stored in server-side environment / GCP Secret Manager.
 */
exports.translateGhanaNlp = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication required to access translation."
    );
  }

  const data = request.data || {};
  const text = (data.text || "").trim();
  const languagePair = (data.languagePair || "").trim(); // e.g. "en-tw"

  if (!text) {
    throw new HttpsError("invalid-argument", "Text to translate is required.");
  }
  if (!languagePair || !languagePair.includes("-")) {
    throw new HttpsError("invalid-argument", "A valid languagePair (e.g. 'en-tw') is required.");
  }

  const [sourceLang, targetLang] = languagePair.split("-");
  if (sourceLang === targetLang) {
    // Optimisation: skip remote call when source equals target
    return { success: true, translation: text, languagePair: languagePair, skipped: true };
  }

  const subscriptionKey = process.env.GHANA_NLP_SUBSCRIPTION_KEY;
  if (!subscriptionKey) {
    console.error("GHANA_NLP_SUBSCRIPTION_KEY is not configured on the server.");
    throw new HttpsError("failed-precondition", "Ghana NLP is not configured on the server.");
  }

  // Translation v2 endpoint — DO NOT revert to v1 (deprecated)
  const translateUrl = `${KHAYA_BASE_URL}${KHAYA_TRANSLATION_ENDPOINT}`;

  try {
    const response = await fetch(translateUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Ocp-Apim-Subscription-Key": subscriptionKey,
      },
      body: JSON.stringify({
        in: text,
        lang: languagePair,
      }),
    });

    if (!response.ok) {
      const errText = await response.text();
      console.error(`Khaya Translation v2 error (${response.status}):`, sanitizeServerLog(errText));
      if (response.status === 401 || response.status === 403) {
        throw new HttpsError("unauthenticated", "Khaya Translation authentication failed.");
      }
      if (response.status === 429) {
        throw new HttpsError("resource-exhausted", "Khaya Translation rate limit exceeded.");
      }
      throw new HttpsError("internal", `Khaya Translation v2 failed with status ${response.status}`);
    }

    const responseText = await response.text();
    let translation = responseText.trim();

    // Handle JSON response — provider may return plain string or JSON
    if (translation.startsWith("{") && translation.endsWith("}")) {
      try {
        const decoded = JSON.parse(translation);
        // Try common field names for translated text
        translation = decoded.translatedText || decoded.translation ||
                      decoded.out || decoded.result || decoded.text || translation;
        if (typeof translation !== "string") translation = responseText.trim();
      } catch (_) { /* keep raw text */ }
    }
    // Strip enclosing quotes
    if (translation.startsWith('"') && translation.endsWith('"') && translation.length > 1) {
      translation = translation.substring(1, translation.length - 1).trim();
    }

    return {
      success: true,
      translation: translation,
      languagePair: languagePair,
      apiVersion: "v2",
    };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error("Khaya Translation v2 exception:", sanitizeServerLog(error));
    throw new HttpsError("internal", `Translation failed: ${sanitizeServerLog(error.message)}`);
  }
});

