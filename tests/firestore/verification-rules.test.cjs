const fs = require('fs');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId: 'blood-connect-12ac2',
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: fs.readFileSync('firestore.rules', 'utf8'),
    },
  });

  try {
    await testEnv.clearFirestore();

    const userId = 'test-user-001';
    const otherUserId = 'test-user-002';
    const adminId = 'test-admin-001';

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('users').doc(userId).set({
        role: 'user',
        idVerificationStatus: 'unverified',
      });
      await db.collection('users').doc(otherUserId).set({ role: 'user' });
      await db.collection('users').doc(adminId).set({ role: 'admin' });
    });

    const userDb = testEnv.authenticatedContext(userId).firestore();
    const otherDb = testEnv.authenticatedContext(otherUserId).firestore();
    const adminDb = testEnv.authenticatedContext(adminId).firestore();
    const guestDb = testEnv.unauthenticatedContext().firestore();
    const doc = userDb.collection('id_verifications').doc(userId);

    const submission = {
      userId,
      submissionId: userId,
      status: 'submitted',
      validationStatus: 'not_checked',
      idType: 'Philippine National ID (PhilSys)',
      // Private uploads made through the backend (POST /api/files).
      frontIdImageUrl: `secure://image/blood_connect_private/${userId}/id_front/front1.jpg`,
      backIdImageUrl: `secure://image/blood_connect_private/${userId}/id_back/back1.png`,
    };

    console.log('TEST 1: Owner creates a one-time ID submission');
    await assertSucceeds(doc.set(submission));

    console.log('TEST 2: Owner reads saved ID');
    await assertSucceeds(doc.get());

    console.log('TEST 3: Admin reads submitted ID');
    await assertSucceeds(adminDb.collection('id_verifications').doc(userId).get());

    console.log('TEST 4: Other user cannot read ID');
    await assertFails(otherDb.collection('id_verifications').doc(userId).get());

    console.log('TEST 5: Unauthenticated user cannot read ID');
    await assertFails(guestDb.collection('id_verifications').doc(userId).get());

    console.log('TEST 6: Owner cannot overwrite saved ID');
    await assertFails(doc.set({ ...submission, idType: 'Other' }));

    console.log('TEST 7: Owner cannot update or self-approve');
    await assertFails(doc.update({ status: 'approved', verified: true }));

    console.log('TEST 8: Owner cannot delete saved ID');
    await assertFails(doc.delete());

    // PRC sets the submission's status when it approves or rejects the
    // blood request it belongs to (admin portal, BloodRequestDetail); the
    // backend notifies the user from that change.
    console.log('TEST 9: Admin can approve or reject a submission');
    await assertSucceeds(adminDb.collection('id_verifications').doc(userId).update({ status: 'approved' }));

    console.log('TEST 10: Other user cannot change a submission');
    await assertFails(otherDb.collection('id_verifications').doc(userId).update({ status: 'rejected' }));

    console.log('TEST 11: Owner cannot create ID under another UID');
    await assertFails(userDb.collection('id_verifications').doc('not-my-uid').set({
      ...submission,
      submissionId: 'not-my-uid',
    }));

    // A valid submission for otherUserId, to vary one field at a time.
    const otherSubmission = {
      ...submission,
      userId: otherUserId,
      submissionId: otherUserId,
      frontIdImageUrl: `secure://image/blood_connect_private/${otherUserId}/id_front/f.jpg`,
      backIdImageUrl: `secure://image/blood_connect_private/${otherUserId}/id_back/b.jpg`,
    };
    const otherDoc = otherDb.collection('id_verifications').doc(otherUserId);

    console.log('TEST 12: Owner cannot create approved submission');
    await assertFails(otherDoc.set({ ...otherSubmission, status: 'approved' }));

    console.log('TEST 13: Owner cannot create submission missing back image');
    const { backIdImageUrl, ...incomplete } = otherSubmission;
    await assertFails(otherDoc.set(incomplete));

    console.log('TEST 13b: Public Cloudinary links are refused for ID photos');
    await assertFails(otherDoc.set({
      ...otherSubmission,
      frontIdImageUrl: 'https://res.cloudinary.com/dlk8chosr/image/upload/v1/front.jpg',
    }));

    console.log("TEST 13c: Another user's private ID photo is refused");
    await assertFails(otherDoc.set({
      ...otherSubmission,
      frontIdImageUrl: submission.frontIdImageUrl,
    }));

    console.log('TEST 13d: The front photo must be an id_front upload');
    await assertFails(otherDoc.set({
      ...otherSubmission,
      frontIdImageUrl: otherSubmission.backIdImageUrl,
    }));

    console.log('TEST 13e: A valid private submission is accepted');
    await assertSucceeds(otherDoc.set(otherSubmission));

    console.log('TEST 14: Owner cannot change account approval status');
    await assertFails(userDb.collection('users').doc(userId).update({
      idVerificationStatus: 'approved',
    }));

    console.log('\nALL 18 ONE-TIME ID SECURITY TESTS PASSED');
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error('TEST FAILED:', error);
  process.exitCode = 1;
});
