// Security rules tests for the blood request / donation offer lifecycle.
//
// Run against the Firestore emulator (requires Java):
//   firebase emulators:exec --only firestore "node tests/firestore/lifecycle-rules.test.cjs"

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
  deleteDoc,
  getDoc,
  getDocs,
  collection,
  collectionGroup,
  query,
  where,
} = require("firebase/firestore");

const PROJECT_ID = "blood-connect-12ac2";
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

  const requesterId = "test-requester-001";
  const donorId = "test-donor-001";
  const unavailableDonorId = "test-donor-unavailable-001";
  const strangerId = "test-stranger-001";
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

  // Resets the shared fixtures so each test starts from a known state.
  async function seed() {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();

      await setDoc(doc(db, "users", adminId), { uid: adminId, role: "admin" });

      // Activated donors always carry the next eligible date PRC set at
      // activation (YYYY-MM-DD); offers require it (R4, fail closed).
      await setDoc(doc(db, "donors", donorId), {
        userId: donorId,
        donorStatus: "approved",
        isDonor: true,
        isAvailableForDonation: true,
        bloodType: "O+",
        nextEligibleDonationDate: "2025-01-15",
      });

      await setDoc(doc(db, "donors", unavailableDonorId), {
        userId: unavailableDonorId,
        donorStatus: "approved",
        isDonor: true,
        isAvailableForDonation: false,
        bloodType: "O+",
        nextEligibleDonationDate: "2025-01-15",
      });

      await setDoc(doc(db, "blood_requests", "open-req"), {
        userId: requesterId,
        requesterId,
        bloodType: "O+",
        status: "active",
      });

      await setDoc(doc(db, "blood_requests", "pending-req"), {
        userId: requesterId,
        requesterId,
        bloodType: "O+",
        status: "pending",
      });

      await setDoc(doc(db, "blood_requests", "fulfilled-req"), {
        userId: requesterId,
        requesterId,
        bloodType: "O+",
        status: "fulfilled",
      });

      await setDoc(doc(db, "request_summaries", "open-req"), {
        requestId: "open-req",
        bloodType: "O+",
        status: "active",
      });

      await setDoc(doc(db, "blood_requests", "open-req", "offers", "offer-1"), {
        requestId: "open-req",
        donorId,
        status: "pending",
      });

      await setDoc(doc(db, "blood_requests", "open-req", "offers", "offer-done"), {
        requestId: "open-req",
        donorId,
        status: "donated",
      });

      // The requester finished identity verification (R5).
      await setDoc(doc(db, "users", requesterId), {
        uid: requesterId,
        role: "user",
        faceVerified: true,
      });
      await setDoc(doc(db, "id_verifications", requesterId), idOnFile(requesterId));
    });
  }

  // id_verifications/{uid} as the app saves it: both private ID photos.
  function idOnFile(uid) {
    return {
      userId: uid,
      status: "submitted",
      idType: "PhilSys National ID",
      frontIdImageUrl: `secure://image/blood_connect_private/${uid}/id_front/front.jpg`,
      backIdImageUrl: `secure://image/blood_connect_private/${uid}/id_back/back.jpg`,
    };
  }

  // Changes the seeded requester's verification before a test.
  async function setRequesterVerification({ faceVerified = true, idPhotos = true } = {}) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "users", requesterId), {
        uid: requesterId,
        role: "user",
        faceVerified,
      });
      if (idPhotos === true) {
        await setDoc(doc(db, "id_verifications", requesterId), idOnFile(requesterId));
      } else if (idPhotos === "front-only") {
        await setDoc(doc(db, "id_verifications", requesterId), {
          ...idOnFile(requesterId),
          backIdImageUrl: "",
        });
      } else {
        await deleteDoc(doc(db, "id_verifications", requesterId));
      }
    });
  }

  const db = (uid) => testEnv.authenticatedContext(uid).firestore();

  const cancel = (uid) => ({
    status: "cancelled",
    cancelledBy: uid,
    cancelledAt: new Date(),
    cancellationReason: "Patient transferred",
  });

  try {
    console.log("\n--- REQUEST CANCELLATION ---\n");

    await seed();
    await test(
      "Requester can cancel their own open request",
      () => updateDoc(doc(db(requesterId), "blood_requests", "open-req"), cancel(requesterId)),
      true
    );

    await seed();
    await test(
      "Requester can cancel their own pending request",
      () => updateDoc(doc(db(requesterId), "blood_requests", "pending-req"), cancel(requesterId)),
      true
    );

    await seed();
    await test(
      "Requester cannot cancel a fulfilled request",
      () => updateDoc(doc(db(requesterId), "blood_requests", "fulfilled-req"), cancel(requesterId)),
      false
    );

    await seed();
    await test(
      "Another user cannot cancel someone else's request",
      () => updateDoc(doc(db(strangerId), "blood_requests", "open-req"), cancel(strangerId)),
      false
    );

    await seed();
    await test(
      "Requester cannot mark their own request fulfilled",
      () => updateDoc(doc(db(requesterId), "blood_requests", "open-req"), {
        status: "fulfilled",
      }),
      false
    );

    const newRequest = (bloodType) => ({
      userId: requesterId,
      requesterId,
      bloodType,
      status: "pending",
    });

    await seed();
    await test(
      "Requester can create a request for a specific blood type",
      () => setDoc(doc(db(requesterId), "blood_requests", "new-req"), newRequest("AB-")),
      true
    );

    // R5: only users who finished identity verification may request blood.
    await seed();
    await setRequesterVerification({ faceVerified: false });
    await test(
      "Requester whose face is not verified cannot create a request",
      () => setDoc(doc(db(requesterId), "blood_requests", "new-req"), newRequest("AB-")),
      false
    );

    await seed();
    await setRequesterVerification({ idPhotos: false });
    await test(
      "Requester without an ID on file cannot create a request",
      () => setDoc(doc(db(requesterId), "blood_requests", "new-req"), newRequest("AB-")),
      false
    );

    await seed();
    await setRequesterVerification({ idPhotos: "front-only" });
    await test(
      "Requester with only the front ID photo cannot create a request",
      () => setDoc(doc(db(requesterId), "blood_requests", "new-req"), newRequest("AB-")),
      false
    );

    await seed();
    await test(
      "A user with no profile cannot create a request",
      () => setDoc(doc(db(strangerId), "blood_requests", "new-req"), {
        userId: strangerId,
        requesterId: strangerId,
        bloodType: "AB-",
        status: "pending",
      }),
      false
    );

    for (const bloodType of ["Any Type", "Any", "", "o+"]) {
      await seed();
      await test(
        `Requester cannot create a request with blood type ${JSON.stringify(bloodType)}`,
        () => setDoc(doc(db(requesterId), "blood_requests", "new-req"), newRequest(bloodType)),
        false
      );
    }

    await seed();
    await test(
      "Requester cannot create a request without a blood type",
      () => setDoc(doc(db(requesterId), "blood_requests", "new-req"), {
        userId: requesterId,
        requesterId,
        status: "pending",
      }),
      false
    );

    await seed();
    await test(
      "Requester can change the blood type to another specific type",
      () => updateDoc(doc(db(requesterId), "blood_requests", "open-req"), { bloodType: "A-" }),
      true
    );

    await seed();
    await test(
      "Requester cannot change the blood type to Any Type",
      () => updateDoc(doc(db(requesterId), "blood_requests", "open-req"), { bloodType: "Any Type" }),
      false
    );

    await seed();
    await test(
      "Requester cannot change other fields while cancelling",
      () => updateDoc(doc(db(requesterId), "blood_requests", "open-req"), {
        ...cancel(requesterId),
        bloodType: "AB-",
      }),
      false
    );

    await seed();
    await test(
      "Requester can close the donor-facing summary when cancelling",
      () => updateDoc(doc(db(requesterId), "request_summaries", "open-req"), {
        status: "cancelled",
        updatedAt: new Date(),
      }),
      true
    );

    await seed();
    await test(
      "Another user cannot close someone else's summary",
      () => updateDoc(doc(db(strangerId), "request_summaries", "open-req"), {
        status: "cancelled",
      }),
      false
    );

    console.log("\n--- OFFERS ---\n");

    const newOffer = (uid, requestId) => ({
      requestId,
      donorId: uid,
      donorBloodType: "O+",
      status: "pending",
      createdAt: new Date(),
    });

    await seed();
    await test(
      "Eligible donor can offer on an open request",
      () => setDoc(
        doc(db(donorId), "blood_requests", "open-req", "offers", "new-offer"),
        newOffer(donorId, "open-req")
      ),
      true
    );

    await seed();
    await test(
      "Donor cannot offer on a request PRC has not approved",
      () => setDoc(
        doc(db(donorId), "blood_requests", "pending-req", "offers", "new-offer"),
        newOffer(donorId, "pending-req")
      ),
      false
    );

    await seed();
    await test(
      "Donor marked unavailable by PRC cannot offer",
      () => setDoc(
        doc(db(unavailableDonorId), "blood_requests", "open-req", "offers", "new-offer"),
        newOffer(unavailableDonorId, "open-req")
      ),
      false
    );

    await seed();
    await test(
      "Non-donor cannot offer",
      () => setDoc(
        doc(db(strangerId), "blood_requests", "open-req", "offers", "new-offer"),
        newOffer(strangerId, "open-req")
      ),
      false
    );

    await seed();
    await test(
      "Donor cannot create a pre-approved offer",
      () => setDoc(
        doc(db(donorId), "blood_requests", "open-req", "offers", "new-offer"),
        { ...newOffer(donorId, "open-req"), status: "approved" }
      ),
      false
    );

    await seed();
    await test(
      "Donor can withdraw their pending offer",
      () => updateDoc(doc(db(donorId), "blood_requests", "open-req", "offers", "offer-1"), {
        status: "withdrawn",
        withdrawnAt: new Date(),
        updatedAt: new Date(),
      }),
      true
    );

    await seed();
    await test(
      "Donor cannot approve their own offer",
      () => updateDoc(doc(db(donorId), "blood_requests", "open-req", "offers", "offer-1"), {
        status: "approved",
      }),
      false
    );

    await seed();
    await test(
      "Donor cannot withdraw an offer already donated",
      () => updateDoc(doc(db(donorId), "blood_requests", "open-req", "offers", "offer-done"), {
        status: "withdrawn",
      }),
      false
    );

    await seed();
    await test(
      "Requester cannot change an offer's status",
      () => updateDoc(doc(db(requesterId), "blood_requests", "open-req", "offers", "offer-1"), {
        status: "approved",
      }),
      false
    );

    await seed();
    await test(
      "PRC admin can confirm an offer",
      () => updateDoc(doc(db(adminId), "blood_requests", "open-req", "offers", "offer-1"), {
        status: "approved",
      }),
      true
    );

    console.log("\n--- READING OFFERS ---\n");

    await seed();
    await test(
      "Donor can list their own offers across requests",
      () => getDocs(query(collectionGroup(db(donorId), "offers"), where("donorId", "==", donorId))),
      true
    );

    await seed();
    await test(
      "User cannot list another donor's offers",
      () => getDocs(query(collectionGroup(db(strangerId), "offers"), where("donorId", "==", donorId))),
      false
    );

    await seed();
    await test(
      "Requester can read offers on their own request",
      () => getDocs(collection(db(requesterId), "blood_requests", "open-req", "offers")),
      true
    );

    await seed();
    await test(
      "Stranger cannot read an offer on someone else's request",
      () => getDoc(doc(db(strangerId), "blood_requests", "open-req", "offers", "offer-1")),
      false
    );

    console.log("\n--- ADMIN-ONLY FIELDS ---\n");

    const forged = {
      archived: false,
      rejectionReason: "x",
      matchingDonorsNotified: 99,
      prcStock: { reservedUnits: 2, pickupInstructions: "x" },
      prcStockNotices: [{ reservedUnits: 2 }],
      reviewChecklist: { brfMatches: true },
    };
    for (const [field, value] of Object.entries(forged)) {
      await seed();
      await test(
        `Requester cannot set ${field} on their own request`,
        () => updateDoc(doc(db(requesterId), "blood_requests", "open-req"), { [field]: value }),
        false
      );
    }

    await seed();
    await test(
      "Requester can still edit ordinary fields on their request",
      () => updateDoc(doc(db(requesterId), "blood_requests", "open-req"), { notes: "Ward 3" }),
      true
    );

    await seed();
    await test(
      "PRC can archive a finished request and record a rejection reason",
      () => updateDoc(doc(db(adminId), "blood_requests", "fulfilled-req"), {
        archived: true,
        rejectionReason: "x",
      }),
      true
    );

    await seed();
    await test(
      "Donor cannot clear PRC's archive flag on their application",
      () => updateDoc(doc(db(donorId), "donors", donorId), { archived: false }),
      false
    );

    console.log("\n--- BLOOD REQUEST FORM UPLOADS ---\n");

    const requestWithBrf = (brfFileUrl) => ({
      userId: requesterId,
      requesterId,
      bloodType: "O+",
      status: "pending",
      brfFileUrl,
    });
    const ownBrf = `secure://raw/blood_connect_private/${requesterId}/brf/form1.pdf`;

    await seed();
    await test(
      "Requester can submit a request with their private Blood Request Form",
      () => setDoc(doc(db(requesterId), "blood_requests", "new-req"), requestWithBrf(ownBrf)),
      true
    );

    await seed();
    await test(
      "A public Cloudinary link is refused as the Blood Request Form",
      () => setDoc(doc(db(requesterId), "blood_requests", "new-req"),
        requestWithBrf("https://res.cloudinary.com/dlk8chosr/raw/upload/v1/form.pdf")),
      false
    );

    await seed();
    await test(
      "Someone else's private Blood Request Form is refused",
      () => setDoc(doc(db(requesterId), "blood_requests", "new-req"),
        requestWithBrf(`secure://raw/blood_connect_private/${strangerId}/brf/form1.pdf`)),
      false
    );

    await seed();
    await test(
      "Requester cannot replace the Blood Request Form after submitting",
      () => updateDoc(doc(db(requesterId), "blood_requests", "open-req"), { brfFileUrl: ownBrf }),
      false
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
