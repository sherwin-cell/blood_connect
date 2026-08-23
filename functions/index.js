/**
 * Blood-Connect Authentication Cloud Functions
 *
 * googleLoginOnly:
 *   Verifies a Google ID token, checks that a Firebase Auth user with the
 *   Google provider already exists, and returns a custom token.
 *   Never creates Auth users or Firestore profiles.
 *
 * blockGoogleAutoRegistration:
 *   beforeCreate blocking function — rejects any attempt to create a new
 *   Firebase Auth user via Google (defense in depth if a client calls
 *   signInWithCredential).
 *
 * submitVerification:
 *   Securely handles ARSA face comparison server-side and updates verificationStatus.
 *
 * Deploy:
 *   cd functions && npm install
 *   firebase deploy --only functions
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { beforeUserCreated } = require("firebase-functions/v2/identity");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { OAuth2Client } = require("google-auth-library");
const axios = require("axios");

initializeApp();

/** Web client ID used by google_sign_in (serverClientId) */
const GOOGLE_WEB_CLIENT_ID =
  "394558242984-d2unmof80o47siujfrkimcu6ljrlin5k.apps.googleusercontent.com";

const oauthClient = new OAuth2Client(GOOGLE_WEB_CLIENT_ID);

/**
 * ARSA Configuration
 * Set ARSA_API_KEY using Firebase secrets/env:
 * firebase functions:secrets:set ARSA_API_KEY
 */
const ARSA_BASE_URL = "https://faceapi.arsa.technology";
const ARSA_API_KEY = process.env.ARSA_API_KEY || "YOUR_DEV_ARSA_KEY";

/**
 * Callable: Google login for EXISTING Google Auth users only.
 */
exports.googleLoginOnly = onCall({ region: "us-central1" }, async (request) => {
  const idToken = request.data?.idToken;
  if (!idToken || typeof idToken !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "Missing Google ID token.",
    );
  }

  let payload;
  try {
    const ticket = await oauthClient.verifyIdToken({
      idToken,
      audience: GOOGLE_WEB_CLIENT_ID,
    });
    payload = ticket.getPayload();
  } catch (_) {
    throw new HttpsError(
      "unauthenticated",
      "Invalid Google credentials.",
    );
  }

  const email = payload?.email;
  if (!email) {
    throw new HttpsError(
      "failed-precondition",
      "Account not found. Please register first.",
    );
  }

  let userRecord;
  try {
    userRecord = await getAuth().getUserByEmail(email);
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      throw new HttpsError(
        "not-found",
        "Account not found. Please register first.",
      );
    }
    throw new HttpsError("internal", "Unable to verify account.");
  }

  if (userRecord.disabled) {
    throw new HttpsError(
      "permission-denied",
      "This account has been disabled.",
    );
  }

  const customToken = await getAuth().createCustomToken(userRecord.uid);
  return { customToken };
});

/**
 * Blocking function: never allow Firebase to auto-create Auth users via Google.
 */
exports.blockGoogleAutoRegistration = beforeUserCreated(
  { region: "us-central1" },
  (event) => {
    const credentialProvider = event.credential?.providerId;
    const providerData = event.data?.providerData || [];
    const isGoogle =
      credentialProvider === "google.com" ||
      providerData.some((p) => p.providerId === "google.com");

    if (isGoogle) {
      throw new HttpsError(
        "permission-denied",
        "Account not found. Please register first.",
      );
    }
  },
);

/**
 * Callable: Secure Verification Processing Engine
 * Handles face comparison server-side and enforces >= 75% auto-approval threshold.
 */
exports.submitVerification = onCall({ region: "us-central1" }, async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "User must be authenticated to submit verification.",
    );
  }

  const uid = request.auth.uid;
  const {
    idImageUrl,
    selfieImageUrl,
    croppedIdFaceBase64,
    selfieBase64,
    livenessPassed,
  } = request.data || {};

  if (!livenessPassed) {
    throw new HttpsError(
      "failed-precondition",
      "Liveness check was not completed successfully.",
    );
  }

  if (!croppedIdFaceBase64 || !selfieBase64) {
    throw new HttpsError(
      "invalid-argument",
      "Missing image payloads for face comparison.",
    );
  }

  let similarityScore = 0;

  try {
    const response = await axios.post(
      `${ARSA_BASE_URL}/compare_faces`,
      {
        image1: croppedIdFaceBase64,
        image2: selfieBase64,
      },
      {
        headers: {
          "Content-Type": "application/json",
          "x-api-key": ARSA_API_KEY,
        },
        timeout: 15000,
      },
    );

    similarityScore = Number(response.data?.similarity || 0);
  } catch (error) {
    console.error("ARSA API Request Error:", error?.response?.data || error.message);
    throw new HttpsError(
      "internal",
      "Face comparison service unavailable. Please try again later.",
    );
  }

  // Business Logic: >= 75% similarity + Liveness -> Approved
  let verificationStatus = "pending";
  if (livenessPassed && similarityScore >= 75.0) {
    verificationStatus = "approved";
  } else if (similarityScore < 50.0) {
    verificationStatus = "rejected";
  }

  const db = getFirestore();
  const userRef = db.collection("users").doc(uid);

  await userRef.set(
    {
      verificationStatus,
      arsaSimilarity: similarityScore,
      idImageUrl: idImageUrl || null,
      selfieImageUrl: selfieImageUrl || null,
      reviewedBy: verificationStatus === "approved" ? "SYSTEM_AUTO" : null,
      reviewedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return {
    status: verificationStatus,
    similarity: similarityScore,
  };
});