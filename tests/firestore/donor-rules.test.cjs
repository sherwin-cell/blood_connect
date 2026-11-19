
const fs = require("node:fs");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");

const {
  doc,
  setDoc,
  updateDoc,
} = require("firebase/firestore");

const PROJECT_ID = "blood-connect-12ac2";

const RULES_PATH =
  "C:/Users/Joyleen/development/blood_connect/firestore.rules";

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
