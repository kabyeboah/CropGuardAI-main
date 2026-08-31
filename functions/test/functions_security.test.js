const test = require("node:test");
const assert = require("node:assert/strict");

// Mock Firestore Transaction and Reference for unit testing functions logic
class MockDocSnapshot {
  constructor(id, data, exists = true) {
    this.id = id;
    this._data = data;
    this.exists = exists;
  }
  data() {
    return this._data;
  }
}

class MockTransaction {
  constructor(docSnapshot) {
    this._snapshot = docSnapshot;
    this.updates = [];
  }
  async get(ref) {
    return this._snapshot;
  }
  update(ref, data) {
    this.updates.push({ ref, data });
  }
}

// Logic under test replicated from verifyOutbreak transaction block
function processOutbreakVerification(reportData, uid, confirm) {
  const rawVerified = Array.isArray(reportData.verifiedBy) ? reportData.verifiedBy : [];
  const rawRefuted = Array.isArray(reportData.refutedBy) ? reportData.refutedBy : [];

  const verifiedSet = new Set(rawVerified);
  const refutedSet = new Set(rawRefuted);

  if (confirm) {
    if (verifiedSet.has(uid) && !refutedSet.has(uid)) {
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

  return {
    status: "updated",
    verifiedBy: updatedVerifiedBy,
    refutedBy: updatedRefutedBy,
    verifiedCount: updatedVerifiedBy.length,
    refutedCount: updatedRefutedBy.length,
    confidenceScore: updatedConfidenceScore,
  };
}

// Notification trigger deduplication check
function shouldSendOutbreakNotification(beforeData, afterData) {
  if (!afterData) return false;

  const verifiedBy = Array.isArray(afterData.verifiedBy) ? afterData.verifiedBy : [];
  const refutedBy = Array.isArray(afterData.refutedBy) ? afterData.refutedBy : [];
  const confidenceScore = afterData.confidenceScore || Math.max(1, 1 + verifiedBy.length - refutedBy.length);

  const isHighConfidence = verifiedBy.length >= 2 || confidenceScore >= 3 || afterData.isHighRisk === true;
  if (!isHighConfidence) return false;

  const previouslyNotified = beforeData && beforeData.notifiedAt != null;
  const previousConfidence = beforeData?.confidenceScore || 0;
  const previousVerifiedCount = Array.isArray(beforeData?.verifiedBy) ? beforeData.verifiedBy.length : 0;

  if (previouslyNotified && verifiedBy.length <= previousVerifiedCount && confidenceScore <= previousConfidence) {
    return false;
  }

  return true;
}

test("Outbreak verification: First confirmation adds user and recalculates confidence", () => {
  const initialData = {
    userId: "author_123",
    disease: "Cassava Mosaic Disease",
    verifiedBy: ["author_123"],
    refutedBy: [],
    confidenceScore: 1,
  };

  const result = processOutbreakVerification(initialData, "farmer_456", true);
  assert.equal(result.status, "updated");
  assert.deepEqual(result.verifiedBy, ["author_123", "farmer_456"]);
  assert.equal(result.verifiedCount, 2);
  assert.equal(result.refutedCount, 0);
  assert.equal(result.confidenceScore, 3); // 1 + 2 - 0 = 3
});

test("Outbreak verification: Duplicate confirmation is idempotent and does not increment confidence", () => {
  const initialData = {
    userId: "author_123",
    disease: "Cassava Mosaic Disease",
    verifiedBy: ["author_123", "farmer_456"],
    refutedBy: [],
    confidenceScore: 3,
  };

  // Same user attempts to verify again
  const result = processOutbreakVerification(initialData, "farmer_456", true);
  assert.equal(result.status, "noop");
  assert.equal(result.verifiedCount, 2);
  assert.equal(result.confidenceScore, 3);
});

test("Outbreak verification: Switching vote from refute to confirm removes from refutedBy", () => {
  const initialData = {
    userId: "author_123",
    disease: "Maize Fall Armyworm",
    verifiedBy: ["author_123"],
    refutedBy: ["farmer_456"],
    confidenceScore: 1,
  };

  const result = processOutbreakVerification(initialData, "farmer_456", true);
  assert.equal(result.status, "updated");
  assert.ok(result.verifiedBy.includes("farmer_456"));
  assert.ok(!result.refutedBy.includes("farmer_456"));
  assert.equal(result.confidenceScore, 3);
});

test("Outbreak verification: Duplicate refutation is idempotent", () => {
  const initialData = {
    userId: "author_123",
    disease: "Tomato Late Blight",
    verifiedBy: ["author_123"],
    refutedBy: ["user_789"],
    confidenceScore: 1,
  };

  const result = processOutbreakVerification(initialData, "user_789", false);
  assert.equal(result.status, "noop");
  assert.equal(result.refutedCount, 1);
});

test("Notification deduplication: High confidence triggers alert on first high-risk state", () => {
  const beforeData = {
    verifiedBy: ["author_1"],
    confidenceScore: 1,
    notifiedAt: null,
  };
  const afterData = {
    verifiedBy: ["author_1", "farmer_2"],
    confidenceScore: 3,
  };

  const shouldSend = shouldSendOutbreakNotification(beforeData, afterData);
  assert.equal(shouldSend, true);
});

test("Notification deduplication: Suppresses duplicate notification for identical report state", () => {
  const beforeData = {
    verifiedBy: ["author_1", "farmer_2"],
    confidenceScore: 3,
    notifiedAt: new Date(),
  };
  const afterData = {
    verifiedBy: ["author_1", "farmer_2"],
    confidenceScore: 3,
    notifiedAt: new Date(),
    notes: "Minor note edit",
  };

  const shouldSend = shouldSendOutbreakNotification(beforeData, afterData);
  assert.equal(shouldSend, false);
});

test("Notification deduplication: Triggers new alert if confidence score increases significantly", () => {
  const beforeData = {
    verifiedBy: ["author_1", "farmer_2"],
    confidenceScore: 3,
    notifiedAt: new Date(),
  };
  const afterData = {
    verifiedBy: ["author_1", "farmer_2", "farmer_3", "farmer_4"],
    confidenceScore: 5,
    notifiedAt: new Date(),
  };

  const shouldSend = shouldSendOutbreakNotification(beforeData, afterData);
  assert.equal(shouldSend, true);
});
