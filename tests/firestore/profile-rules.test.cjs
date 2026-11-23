// Security rules tests for the Profile feature (Item 17).
//
// Edit Profile and Notification Settings update users/{uid} with owner-
// editable fields only; account deletion goes through the backend, so the
// owner cannot delete users/{uid} directly. account_deletions is backend-only.
//
// Run against the Firestore emulator (requires Java 21):
//   firebase emulators:exec --only firestore "node tests/firestore/profile-rules.test.cjs"

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
  deleteDoc,
  deleteField,
  serverTimestamp,
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

  const userId = "profile-user-001";
  const otherId = "profile-other-001";
  const adminId = "profile-admin-001";

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
        email: "user@example.test",
        fullName: "Old Name",
        phoneNumber: "09170000000",
        gender: "Female",
        purok: "Purok 1",
        faceVerified: false,
        profileCompleted: true,
      });
      await setDoc(doc(db, "users", otherId), { uid: otherId, role: "user" });
      await setDoc(doc(db, "users", userId, "fcm_tokens", "tok-1"), {
        token: "tok-1",
        platform: "android",
      });
      await setDoc(doc(db, "account_deletions", "gone-user"), {
        summary: { users: 1 },
      });
    });
  }

  const db = (uid) => testEnv.authenticatedContext(uid).firestore();

  // Same shape as PersonalInfoUpdate.toFirestore() in the app.
  const editProfile = {
    fullName: "New Name",
    phoneNumber: "09123456789",
    birthday: "2000-05-14",
    gender: deleteField(),
    nationality: "Filipino",
    purok: "Purok 3",
    barangay: "Burabod",
    municipality: "Sorsogon City",
    province: "Sorsogon",
    updatedAt: serverTimestamp(),
  };

  try {
    // ---------------------------------------------------------------
    // Edit Profile
    // ---------------------------------------------------------------
    await seed();
    await test(
      "Owner can save Edit Profile fields (including clearing one)",
      () => updateDoc(doc(db(userId), "users", userId), editProfile),
      true
    );

    await seed();
    await test(
      "Owner can set photoUrl",
      () =>
        updateDoc(doc(db(userId), "users", userId), {
          photoUrl: "https://res.cloudinary.com/dlk8chosr/image/upload/v1/p.jpg",
          updatedAt: serverTimestamp(),
        }),
      true
    );

    await seed();
    await test(
      "Another user cannot edit this profile",
      () => updateDoc(doc(db(otherId), "users", userId), editProfile),
      false
    );

    await seed();
    await test(
      "Edit Profile cannot sneak in faceVerified",
      () =>
        updateDoc(doc(db(userId), "users", userId), {
          ...editProfile,
          faceVerified: true,
        }),
      false
    );

    await seed();
    await test(
      "Edit Profile cannot change role",
      () =>
        updateDoc(doc(db(userId), "users", userId), {
          fullName: "x",
          role: "admin",
        }),
      false
    );

    // ---------------------------------------------------------------
    // Notification Settings
    // ---------------------------------------------------------------
    await seed();
    await test(
      "Owner can save notificationPreferences as a map",
      () =>
        updateDoc(doc(db(userId), "users", userId), {
          notificationPreferences: {
            requestUpdates: true,
            donorAlerts: false,
            donationUpdates: true,
            chatMessages: true,
            announcements: false,
          },
          updatedAt: serverTimestamp(),
        }),
      true
    );

    await seed();
    await test(
      "notificationPreferences must be a map",
      () =>
        updateDoc(doc(db(userId), "users", userId), {
          notificationPreferences: "off",
        }),
      false
    );

    // ---------------------------------------------------------------
    // Log out / delete account
    // ---------------------------------------------------------------
    await seed();
    await test(
      "Owner can remove this device's FCM token on log out",
      () => deleteDoc(doc(db(userId), "users", userId, "fcm_tokens", "tok-1")),
      true
    );

    await seed();
    await test(
      "Another user cannot remove someone's FCM token",
      () => deleteDoc(doc(db(otherId), "users", userId, "fcm_tokens", "tok-1")),
      false
    );

    await seed();
    await test(
      "Owner cannot delete users/{uid} directly (backend deletes accounts)",
      () => deleteDoc(doc(db(userId), "users", userId)),
      false
    );

    await seed();
    await test(
      "Users cannot read account_deletions",
      () => getDoc(doc(db(userId), "account_deletions", "gone-user")),
      false
    );

    await seed();
    await test(
      "Users cannot write account_deletions",
      () => setDoc(doc(db(userId), "account_deletions", userId), { x: 1 }),
      false
    );

    await seed();
    await test(
      "Admins can read account_deletions",
      () => getDoc(doc(db(adminId), "account_deletions", "gone-user")),
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
