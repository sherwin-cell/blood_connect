// Security rules tests for the Matching Center changes.
//
// - blood_requests and donors are readable only by their owner and PRC;
//   donors read the anonymised request_summaries instead.
// - Offers: eligible donor, exact blood type, never on your own request.
// - Donor anonymity: PRC alone sets an offer's donorCode and the request's
//   matchedDonorCodes; the donor-code counter is PRC-only.
// - Chats: only participants (and PRC) read support chats; retired
//   donor-match chats are PRC-only: users can neither read nor write them.
//
// Run against the Firestore emulator (requires Java 21):
//   firebase emulators:exec --only firestore "node tests/firestore/matching-rules.test.cjs"

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
  addDoc,
  collection,
  query,
  where,
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

  const requester = "m-requester";
  const donor = "m-donor"; // approved A+ donor
  const otherDonor = "m-donor-b"; // approved B+ donor
  const stranger = "m-stranger";
  const admin = "m-admin";
  const requestId = "m-request-1";
  const offerId = "m-offer-1";
  const matchChat = `match_${requestId}_${offerId}`;

  let passed = 0;
  let failed = 0;

  async function test(name, operation, shouldSucceed) {
    try {
      if (shouldSucceed) await assertSucceeds(operation());
      else await assertFails(operation());
      console.log(`PASS: ${name}`);
      passed++;
    } catch (error) {
      console.error(`FAIL: ${name}`);
      console.error(error.message);
      failed++;
    }
  }

  const approvedDonor = (uid, bloodType) => ({
    userId: uid,
    bloodType,
    donorStatus: "approved",
    isDonor: true,
    isAvailableForDonation: true,
    fullName: `Donor ${uid}`,
    mobileNo: "09170000000",
    eligibilityAnswers: { 1: false },
  });

  async function seed() {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "users", admin), { uid: admin, role: "admin" });
      for (const uid of [requester, donor, otherDonor, stranger]) {
        await setDoc(doc(db, "users", uid), { uid, role: "user" });
      }
      await setDoc(doc(db, "donors", donor), approvedDonor(donor, "A+"));
      await setDoc(doc(db, "donors", otherDonor), approvedDonor(otherDonor, "B+"));
      // The requester is also an approved A+ donor.
      await setDoc(doc(db, "donors", requester), approvedDonor(requester, "A+"));
      await setDoc(doc(db, "blood_requests", requestId), {
        userId: requester,
        requesterId: requester,
        status: "active",
        bloodType: "A+",
        patientName: "Juan Dela Cruz",
        contactNumber: "09999999999",
        hospitalName: "Sorsogon Provincial Hospital",
      });
      await setDoc(doc(db, "request_summaries", requestId), {
        requestId,
        status: "active",
        bloodType: "A+",
        hospitalName: "Sorsogon Provincial Hospital",
      });
      await setDoc(doc(db, "blood_requests", requestId, "offers", offerId), {
        requestId,
        donorId: donor,
        status: "approved",
        donorBloodType: "A+",
        donorCode: "DNR-0001",
      });
      await setDoc(doc(db, "chats", matchChat), {
        chatId: matchChat,
        type: "donor_match",
        requestId,
        offerId,
        participants: [requester, donor],
      });
      await setDoc(doc(db, "chats", matchChat, "messages", "msg-1"), {
        senderId: donor,
        message: "Hello",
      });
      await setDoc(doc(db, "chats", `${requester}_prc_support`), {
        chatId: `${requester}_prc_support`,
        isPrcSupport: true,
        participants: [requester, "prc_support_admin"],
      });
    });
  }

  const db = (uid) => testEnv.authenticatedContext(uid).firestore();
  const offer = (uid, bloodType) => ({
    requestId,
    donorId: uid,
    donorBloodType: bloodType,
    status: "pending",
    createdAt: serverTimestamp(),
  });

  try {
    // ---------------------------------------------------------------
    // blood_requests / request_summaries / donors
    // ---------------------------------------------------------------
    await seed();
    await test("Owner reads their blood request",
      () => getDoc(doc(db(requester), "blood_requests", requestId)), true);
    await test("Owner queries their own requests",
      () => getDocs(query(collection(db(requester), "blood_requests"),
        where("userId", "==", requester))), true);
    await test("A donor cannot read the full blood request",
      () => getDoc(doc(db(donor), "blood_requests", requestId)), false);
    await test("A donor cannot list blood requests by blood type",
      () => getDocs(query(collection(db(donor), "blood_requests"),
        where("bloodType", "==", "A+"))), false);
    await test("Admin reads the blood request",
      () => getDoc(doc(db(admin), "blood_requests", requestId)), true);
    await test("Any signed-in user reads the anonymised summary",
      () => getDoc(doc(db(stranger), "request_summaries", requestId)), true);
    await test("Donor reads their own application",
      () => getDoc(doc(db(donor), "donors", donor)), true);
    await test("Another user cannot read a donor application",
      () => getDoc(doc(db(requester), "donors", donor)), false);
    await test("Nobody can list donors by blood type",
      () => getDocs(query(collection(db(requester), "donors"),
        where("bloodType", "==", "A+"))), false);
    await test("Admin reads donor applications",
      () => getDoc(doc(db(admin), "donors", donor)), true);

    // ---------------------------------------------------------------
    // Offers
    // ---------------------------------------------------------------
    await seed();
    await test("Matching approved donor can offer",
      () => addDoc(collection(db(donor), "blood_requests", requestId, "offers"),
        offer(donor, "A+")), true);
    await seed();
    await test("Donor with another blood type cannot offer",
      () => addDoc(collection(db(otherDonor), "blood_requests", requestId, "offers"),
        offer(otherDonor, "B+")), false);
    await seed();
    await test("Requester cannot offer on their own request",
      () => addDoc(collection(db(requester), "blood_requests", requestId, "offers"),
        offer(requester, "A+")), false);
    await seed();
    await test("Requester can read offers on their request",
      () => getDocs(collection(db(requester), "blood_requests", requestId, "offers")),
      true);

    // ---------------------------------------------------------------
    // Donor anonymity: offers are readable by the requester, so they
    // must never carry the donor's name or contact (R1).
    // ---------------------------------------------------------------
    await seed();
    await test("A donor cannot put their name on a new offer",
      () => addDoc(collection(db(donor), "blood_requests", requestId, "offers"),
        { ...offer(donor, "A+"), donorName: "Maria Santos" }), false);
    await test("A donor cannot put their contact number on a new offer",
      () => addDoc(collection(db(donor), "blood_requests", requestId, "offers"),
        { ...offer(donor, "A+"), donorContact: "09171234567" }), false);
    await test("A donor cannot put their email on a new offer",
      () => addDoc(collection(db(donor), "blood_requests", requestId, "offers"),
        { ...offer(donor, "A+"), donorEmail: "maria@example.test" }), false);
    await test("A donor cannot add their name to an existing offer",
      () => updateDoc(doc(db(donor), "blood_requests", requestId, "offers", offerId),
        { donorName: "Maria Santos" }), false);

    // R2: the offer's blood type is fixed when the donor offers.
    await test("A donor cannot change the blood type on their offer",
      () => updateDoc(doc(db(donor), "blood_requests", requestId, "offers", offerId),
        { donorBloodType: "O-" }), false);

    // ---------------------------------------------------------------
    // Donor codes (anonymised DNR-xxxx)
    // ---------------------------------------------------------------
    await seed();
    await test("A donor cannot preset a donor code on a new offer",
      () => addDoc(collection(db(donor), "blood_requests", requestId, "offers"),
        { ...offer(donor, "A+"), donorCode: "DNR-0001" }), false);
    await test("A donor cannot change their offer's donor code",
      () => updateDoc(doc(db(donor), "blood_requests", requestId, "offers", offerId),
        { donorCode: "DNR-9999" }), false);
    await test("Requester cannot set matchedDonorCodes",
      () => updateDoc(doc(db(requester), "blood_requests", requestId),
        { matchedDonorCodes: ["DNR-0001"] }), false);
    await test("Users cannot read the donor-code counter",
      () => getDoc(doc(db(requester), "counters", "donorCodes")), false);
    await test("Users cannot advance the donor-code counter",
      () => setDoc(doc(db(donor), "counters", "donorCodes"), { last: 5 }), false);
    await test("Admin assigns a donor code",
      () => updateDoc(doc(db(admin), "blood_requests", requestId, "offers", offerId),
        { donorCode: "DNR-0001" }), true);
    await test("Admin lists the code on the request",
      () => updateDoc(doc(db(admin), "blood_requests", requestId),
        { matchedDonorCodes: ["DNR-0001"] }), true);
    await test("Admin advances the donor-code counter",
      () => setDoc(doc(db(admin), "counters", "donorCodes"), { last: 1 }), true);

    // ---------------------------------------------------------------
    // Chats
    // ---------------------------------------------------------------
    await seed();
    await test("Participants can no longer read a retired match chat",
      () => getDoc(doc(db(donor), "chats", matchChat)), false);
    await test("A stranger cannot read the match chat",
      () => getDoc(doc(db(stranger), "chats", matchChat)), false);
    await test("A stranger cannot read someone's PRC support chat",
      () => getDoc(doc(db(stranger), "chats", `${requester}_prc_support`)), false);
    await test("Owner reads their PRC support chat",
      () => getDoc(doc(db(requester), "chats", `${requester}_prc_support`)), true);
    await test("A stranger cannot read match chat messages",
      () => getDocs(collection(db(stranger), "chats", matchChat, "messages")), false);
    await test("Participants can no longer read match chat messages",
      () => getDocs(collection(db(requester), "chats", matchChat, "messages")), false);
    await test("Participants can no longer message in a match chat",
      () => addDoc(collection(db(requester), "chats", matchChat, "messages"),
        { senderId: requester, message: "Thanks!", createdAt: serverTimestamp() }), false);
    await test("Participant cannot update a match chat",
      () => updateDoc(doc(db(requester), "chats", matchChat),
        { lastMessage: "Thanks!", lastSenderId: requester }), false);
    await test("Participants cannot be changed",
      () => updateDoc(doc(db(requester), "chats", matchChat),
        { participants: [requester, stranger] }), false);
    await test("A match chat cannot be flagged as PRC support",
      () => updateDoc(doc(db(donor), "chats", matchChat), { isPrcSupport: true }),
      false);
    await test("Owner messages PRC in their support chat",
      () => addDoc(collection(db(requester), "chats", `${requester}_prc_support`, "messages"),
        { senderId: requester, message: "Hello PRC", createdAt: serverTimestamp() }), true);
    await test("Owner cannot send as someone else in their support chat",
      () => addDoc(collection(db(requester), "chats", `${requester}_prc_support`, "messages"),
        { senderId: donor, message: "fake", createdAt: serverTimestamp() }), false);
    await test("Owner updates their support chat preview",
      () => updateDoc(doc(db(requester), "chats", `${requester}_prc_support`),
        { lastMessage: "Hello PRC" }), true);
    await test("Admin reads match chat messages",
      () => getDocs(collection(db(admin), "chats", matchChat, "messages")), true);

    await seed();
    await test("The app cannot create a donor-match chat",
      () => setDoc(doc(db(requester), "chats", "match_x_y"), {
        type: "donor_match",
        requestId: "x",
        offerId: "y",
        participants: [requester, otherDonor],
      }), false);
    await test("The app cannot open a direct chat with any donor",
      () => setDoc(doc(db(requester), "chats", `${requester}_${otherDonor}`), {
        participants: [requester, otherDonor],
      }), false);
    await test("User creates their own PRC support chat",
      () => setDoc(doc(db(stranger), "chats", `${stranger}_prc_support`), {
        chatId: `${stranger}_prc_support`,
        participants: [stranger, "prc_support_admin"],
      }), true);
    await test("User cannot create someone else's PRC support chat",
      () => setDoc(doc(db(stranger), "chats", `${requester}_prc_support`), {
        participants: [stranger, "prc_support_admin"],
      }), false);
    await seed();
    await test("Support chat greeting may come from PRC in your own chat",
      () => addDoc(collection(db(requester), "chats", `${requester}_prc_support`, "messages"),
        { senderId: "prc_support_admin", message: "Hi", createdAt: serverTimestamp() }),
      true);
    await test("Admin reads any chat",
      () => getDoc(doc(db(admin), "chats", matchChat)), true);

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
