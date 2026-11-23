// Security rules tests for face verification data.
//
// users/{uid}.faceVerified and .faceVerification are written only by the
// backend (Admin SDK) or a PRC admin. face_verification_attempts and
// face_verification_quota are backend-only: admins read, nobody writes.
//
// Run against the Firestore emulator (requires Java 21):
//   firebase emulators:exec --only firestore "node tests/firestore/face-verification-rules.test.cjs"

const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  setDoc,
  updateDoc,
  getDoc,
  getDocs,
  deleteDoc,
  addDoc,
  collection,
  query,
  where,
} = require("firebase/firestore");

const PROJECT_ID = "blood-connect-12ac2";
const RULES_PATH = path.join(__dirname, "..", "..", "firestore.rules");

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: "127.0.0.1",
      port: 8080,
      rules: fs.readFileSync(RULES_PATH, "utf8"),
    },
  });

  const userId = "face-user-001";
  const newUserId = "face-new-user-001";
  const otherId = "face-other-001";
  const adminId = "face-admin-001";

  let passed = 0;
  let failed = 0;

  async function test(name, operation, shouldSucceed) {
    try {
      if (shouldSucceed) {
        await assertSucceeds(operation());
      } else {
        await assertFails(operation());
      }
      console.log(`PASS: ${name}`);
      passed++;
    } catch (error) {
      console.error(`FAIL: ${name}`);
      console.error(error.message);
      failed++;
    }
  }

  async function seed() {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "users", adminId), { uid: adminId, role: "admin" });
      await setDoc(doc(db, "users", userId), {
        uid: userId,
        role: "user",
        fullName: "Test User",
        faceVerified: false,
        faceVerification: { result: "failed", score: 0.12, passed: false },
      });
      await setDoc(doc(db, "users", otherId), { uid: otherId, role: "user" });
      await setDoc(doc(db, "face_verification_attempts", "attempt-1"), {
        userId,
        day: "2026-11-23",
        outcome: "not_matched",
        counted: true,
        score: 0.12,
      });
      await setDoc(doc(db, "face_verification_quota", `${userId}_2026-11-23`), {
        userId,
        day: "2026-11-23",
        count: 5,
      });
    });
  }

  const db = (uid) => testEnv.authenticatedContext(uid).firestore();
  const guest = () => testEnv.unauthenticatedContext().firestore();

  try {
    // ------------------------------------------------------------------
    // users/{uid}: verification fields are not client-writable
    // ------------------------------------------------------------------

    await seed();
    await test(
      "Owner cannot set faceVerified: true",
      () => updateDoc(doc(db(userId), "users", userId), { faceVerified: true }),
      false
    );

    await seed();
    await test(
      "Owner cannot rewrite the faceVerification map",
      () => updateDoc(doc(db(userId), "users", userId), {
        faceVerification: { result: "verified", passed: true, score: 0.99 },
      }),
      false
    );

    await seed();
    await test(
      "Owner cannot change a nested faceVerification field",
      () => updateDoc(doc(db(userId), "users", userId), { "faceVerification.passed": true }),
      false
    );

    await seed();
    await test(
      "Owner cannot sneak faceVerified in with a profile edit",
      () => setDoc(doc(db(userId), "users", userId),
        { fullName: "New Name", faceVerified: true }, { merge: true }),
      false
    );

    await seed();
    await test(
      "Owner can still edit ordinary profile fields",
      () => updateDoc(doc(db(userId), "users", userId), { fullName: "New Name" }),
      true
    );

    await seed();
    await test(
      "New account cannot start verified",
      () => setDoc(doc(db(newUserId), "users", newUserId), {
        uid: newUserId, role: "user", faceVerified: true,
      }),
      false
    );

    await seed();
    await test(
      "New account cannot plant a faceVerification map",
      () => setDoc(doc(db(newUserId), "users", newUserId), {
        uid: newUserId, role: "user", faceVerified: false,
        faceVerification: { result: "verified", score: 0.99, provider: "opencv_sface" },
      }),
      false
    );

    await seed();
    await test(
      "New account without verification fields is allowed",
      () => setDoc(doc(db(newUserId), "users", newUserId), {
        uid: newUserId, role: "user", faceVerified: false,
      }),
      true
    );

    await seed();
    await test(
      "Another user cannot mark someone verified",
      () => updateDoc(doc(db(otherId), "users", userId), { faceVerified: true }),
      false
    );

    await seed();
    await test(
      "PRC admin can manually approve a user",
      () => updateDoc(doc(db(adminId), "users", userId), {
        faceVerified: true,
        faceVerification: { result: "approved_by_admin", reviewedBy: adminId },
      }),
      true
    );

    // ------------------------------------------------------------------
    // id_verifications: the ID-first flow must be able to check for an ID
    // ------------------------------------------------------------------

    await seed();
    await test(
      "Owner can check for their ID before submitting one (missing doc)",
      () => getDoc(doc(db(newUserId), "id_verifications", newUserId)),
      true
    );

    await seed();
    await test(
      "Another user still cannot probe someone else's ID record",
      () => getDoc(doc(db(otherId), "id_verifications", newUserId)),
      false
    );

    await seed();
    await test(
      "Guest cannot probe ID records",
      () => getDoc(doc(guest(), "id_verifications", newUserId)),
      false
    );

    // ------------------------------------------------------------------
    // face_verification_attempts: admin read, no client writes
    // ------------------------------------------------------------------

    await seed();
    await test(
      "Admin can read attempt history",
      () => getDocs(query(collection(db(adminId), "face_verification_attempts"),
        where("userId", "==", userId))),
      true
    );

    await seed();
    await test(
      "User cannot read their own attempt log",
      () => getDoc(doc(db(userId), "face_verification_attempts", "attempt-1")),
      false
    );

    await seed();
    await test(
      "Guest cannot read attempts",
      () => getDoc(doc(guest(), "face_verification_attempts", "attempt-1")),
      false
    );

    await seed();
    await test(
      "User cannot forge a passed attempt",
      () => addDoc(collection(db(userId), "face_verification_attempts"), {
        userId, outcome: "verified", passed: true, score: 0.99,
      }),
      false
    );

    await seed();
    await test(
      "User cannot delete their attempt history",
      () => deleteDoc(doc(db(userId), "face_verification_attempts", "attempt-1")),
      false
    );

    await seed();
    await test(
      "Admin cannot write attempts either (backend only)",
      () => updateDoc(doc(db(adminId), "face_verification_attempts", "attempt-1"),
        { outcome: "verified" }),
      false
    );

    // ------------------------------------------------------------------
    // face_verification_quota: admin read, no client writes
    // ------------------------------------------------------------------

    await seed();
    await test(
      "User cannot reset their daily attempt counter",
      () => updateDoc(doc(db(userId), "face_verification_quota", `${userId}_2026-11-23`),
        { count: 0 }),
      false
    );

    await seed();
    await test(
      "User cannot delete their daily attempt counter",
      () => deleteDoc(doc(db(userId), "face_verification_quota", `${userId}_2026-11-23`)),
      false
    );

    await seed();
    await test(
      "User cannot pre-create tomorrow's counter",
      () => setDoc(doc(db(userId), "face_verification_quota", `${userId}_2026-11-24`),
        { userId, day: "2026-11-24", count: -100 }),
      false
    );

    await seed();
    await test(
      "User cannot read the counter",
      () => getDoc(doc(db(userId), "face_verification_quota", `${userId}_2026-11-23`)),
      false
    );

    await seed();
    await test(
      "Admin can read the counter",
      () => getDoc(doc(db(adminId), "face_verification_quota", `${userId}_2026-11-23`)),
      true
    );

    console.log("\n--- TEST SUMMARY ---");
    console.log(`Passed: ${passed}`);
    console.log(`Failed: ${failed}`);
    if (failed > 0) process.exitCode = 1;
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error("Test setup failed:", error);
  process.exitCode = 1;
});
