
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
  deleteField,
} = require("firebase/firestore");

const PROJECT_ID = "blood-connect-12ac2";

// Relative to this file, so the suite runs on any machine (and in CI).
const RULES_PATH = path.join(__dirname, "..", "..", "firestore.rules");

async function main() {
  const rules = fs.readFileSync(RULES_PATH, "utf8");

  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: "127.0.0.1",
      port: 8080,
      rules,
    },
  });

  const donorId = "test-donor-001";
  const adminId = "test-prc-admin-001";
  const rejectedId = "test-donor-rejected-001";
  const allowedId = "test-donor-allowed-001";
  const newApplicantId = "test-donor-new-001";
  const faceUnverifiedId = "test-donor-face-unverified-001";
  const noIdApplicantId = "test-donor-no-id-001";

  // Same shape as the app's donor application (FirestoreService
  // _submitDonorApplication): a full replacement, always pending.
  const application = (uid, applicationId, extra = {}) => ({
    userId: uid,
    fullName: "Applicant",
    bloodType: "A+",
    applicationId,
    applicationStatus: "pending",
    donorStatus: "pending",
    status: "pending",
    ...extra,
  });

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

  try {
    // Create test records without applying security rules.
    // This is only possible in the emulator.
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();

      await setDoc(doc(db, "users", adminId), {
        uid: adminId,
        role: "admin",
        fullName: "PRC Test Administrator",
      });

      await setDoc(doc(db, "users", donorId), {
        uid: donorId,
        role: "user",
        fullName: "Test Donor",
      });

      await setDoc(doc(db, "donors", donorId), {
        userId: donorId,
        fullName: "Test Donor",
        bloodType: "O+",
        donorStatus: "approved",
        applicationStatus: "approved",
        donorActivationStatus: "active",
        isDonor: true,
        screeningStatus: "completed",
        collectionStatus: "completed",
        donationAvailabilityStatus: "medical_hold",
        nextEligibleDonationDate: "2027-01-22",
      });

      // Identity verification (R5): face matched and an ID on file.
      const idOnFile = (uid) => ({
        userId: uid,
        status: "submitted",
        frontIdImageUrl: `secure://image/blood_connect_private/${uid}/id_front/front.jpg`,
        backIdImageUrl: `secure://image/blood_connect_private/${uid}/id_back/back.jpg`,
      });
      for (const uid of [newApplicantId, allowedId, rejectedId]) {
        await setDoc(doc(db, "users", uid), { uid, role: "user", faceVerified: true });
        await setDoc(doc(db, "id_verifications", uid), idOnFile(uid));
      }
      // ID on file, but the face check has not passed.
      await setDoc(doc(db, "users", faceUnverifiedId), {
        uid: faceUnverifiedId,
        role: "user",
        faceVerified: false,
      });
      await setDoc(doc(db, "id_verifications", faceUnverifiedId), idOnFile(faceUnverifiedId));
      // Face verified, but no ID on file.
      await setDoc(doc(db, "users", noIdApplicantId), {
        uid: noIdApplicantId,
        role: "user",
        faceVerified: true,
      });

      // Rejected; PRC did not allow reapplication.
      await setDoc(doc(db, "donors", rejectedId), {
        userId: rejectedId,
        fullName: "Rejected Donor",
        bloodType: "B+",
        applicationId: "app-rejected-1",
        applicationStatus: "rejected",
        donorStatus: "rejected",
        status: "rejected",
        rejectionReason: "Test rejection",
        reapplicationAllowed: false,
      });

      // Rejected; PRC allowed reapplication.
      await setDoc(doc(db, "donors", allowedId), {
        userId: allowedId,
        fullName: "Allowed Donor",
        bloodType: "B+",
        applicationId: "app-allowed-1",
        applicationStatus: "rejected",
        donorStatus: "rejected",
        status: "rejected",
        rejectionReason: "Test rejection",
        reapplicationAllowed: true,
      });
    });

    const donorDb = testEnv
      .authenticatedContext(donorId)
      .firestore();

    const adminDb = testEnv
      .authenticatedContext(adminId)
      .firestore();

    const donorRef = doc(donorDb, "donors", donorId);
    const adminDonorRef = doc(adminDb, "donors", donorId);

    console.log("\n--- DONOR SECURITY TESTS ---\n");

    await test(
      "Donor can update ordinary profile information",
      () => updateDoc(donorRef, {
        fullName: "Updated Test Donor",
      }),
      true
    );

    await test(
      "Donor cannot mark themselves available",
      () => updateDoc(donorRef, {
        donationAvailabilityStatus: "available",
      }),
      false
    );

    await test(
      "Donor cannot change next eligible donation date",
      () => updateDoc(donorRef, {
        nextEligibleDonationDate: "2026-01-01",
      }),
      false
    );

    await test(
      "Donor cannot change screening status",
      () => updateDoc(donorRef, {
        screeningStatus: "eligible",
      }),
      false
    );

    await test(
      "Donor cannot activate themselves",
      () => updateDoc(donorRef, {
        donorActivationStatus: "active",
        activatedBy: donorId,
      }),
      false
    );

    await test(
      "Donor cannot change their own admin role",
      () => updateDoc(
        doc(donorDb, "users", donorId),
        { role: "admin" }
      ),
      false
    );

    await test(
      "PRC administrator can update donor availability",
      () => updateDoc(adminDonorRef, {
        donationAvailabilityStatus: "available",
        availabilityReview: {
          status: "available",
          notes: "Test clearance only",
          clearanceConfirmed: true,
          reviewedBy: adminId,
          reviewedAt: new Date(),
        },
      }),
      true
    );

    console.log("\n--- BLOOD TYPE (R2) ---\n");

    await test(
      "Approved donor cannot change their own blood type",
      () => updateDoc(donorRef, { bloodType: "AB+" }),
      false
    );

    await test(
      "Donor cannot remove their blood type",
      () => updateDoc(donorRef, { bloodType: deleteField() }),
      false
    );

    await test(
      "PRC administrator can correct a donor's blood type",
      () => updateDoc(adminDonorRef, { bloodType: "O-" }),
      true
    );

    console.log("\n--- REAPPLICATION (R3) ---\n");

    const dbOf = (uid) => testEnv.authenticatedContext(uid).firestore();

    await test(
      "Rejected applicant cannot allow their own reapplication",
      () => updateDoc(doc(dbOf(rejectedId), "donors", rejectedId), {
        reapplicationAllowed: true,
      }),
      false
    );

    await test(
      "Rejected applicant cannot reapply when PRC did not allow it",
      () => setDoc(
        doc(dbOf(rejectedId), "donors", rejectedId),
        application(rejectedId, "app-rejected-2")
      ),
      false
    );

    await test(
      "Approved donor cannot set reapplicationAllowed",
      () => updateDoc(donorRef, { reapplicationAllowed: true }),
      false
    );

    await test(
      "A new application cannot carry reapplicationAllowed",
      () => setDoc(
        doc(dbOf(newApplicantId), "donors", newApplicantId),
        application(newApplicantId, "app-new-1", { reapplicationAllowed: true })
      ),
      false
    );

    await test(
      "A new application without reapplicationAllowed is accepted",
      () => setDoc(
        doc(dbOf(newApplicantId), "donors", newApplicantId),
        application(newApplicantId, "app-new-1")
      ),
      true
    );

    await test(
      "A reapplication cannot keep reapplicationAllowed",
      () => setDoc(
        doc(dbOf(allowedId), "donors", allowedId),
        application(allowedId, "app-allowed-2", { reapplicationAllowed: true })
      ),
      false
    );

    await test(
      "Rejected applicant PRC allowed can reapply with a new blood type",
      () => setDoc(
        doc(dbOf(allowedId), "donors", allowedId),
        application(allowedId, "app-allowed-2", { bloodType: "AB-" })
      ),
      true
    );

    console.log("\n--- IDENTITY VERIFICATION (R5) ---\n");

    await test(
      "Applicant whose face is not verified cannot apply as a donor",
      () => setDoc(
        doc(dbOf(faceUnverifiedId), "donors", faceUnverifiedId),
        application(faceUnverifiedId, "app-face-1")
      ),
      false
    );

    await test(
      "Applicant without an ID on file cannot apply as a donor",
      () => setDoc(
        doc(dbOf(noIdApplicantId), "donors", noIdApplicantId),
        application(noIdApplicantId, "app-noid-1")
      ),
      false
    );

    await test(
      "PRC administrator can allow reapplication",
      () => updateDoc(doc(adminDb, "donors", rejectedId), {
        reapplicationAllowed: true,
      }),
      true
    );

    console.log("\n--- TEST SUMMARY ---");
    console.log(`Passed: ${passed}`);
    console.log(`Failed: ${failed}`);

    if (failed > 0) {
      process.exitCode = 1;
    }
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error("Test setup failed:", error);
  process.exitCode = 1;
});
