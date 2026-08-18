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
 * Deploy:
 *   cd functions && npm install
 *   firebase deploy --only functions
 *
 * Requires Identity Platform (or Firebase Auth blocking functions) enabled
 * for beforeUserCreated.
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { beforeUserCreated } = require("firebase-functions/v2/identity");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { OAuth2Client } = require("google-auth-library");

initializeApp();

/** Web client ID used by google_sign_in (serverClientId) */
const GOOGLE_WEB_CLIENT_ID =
  "394558242984-d2unmof80o47siujfrkimcu6ljrlin5k.apps.googleusercontent.com";

const oauthClient = new OAuth2Client(GOOGLE_WEB_CLIENT_ID);

/**
 * Callable: Google login for EXISTING Google Auth users only.
 * Request: { idToken: string }
 * Response: { customToken: string }
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

  // Existing Blood-Connect Auth user (email/password or Google) → custom token.
  // Never creates a new Auth user; signInWithCustomToken only authenticates.
  const customToken = await getAuth().createCustomToken(userRecord.uid);
  return { customToken };
});

/**
 * Blocking function: never allow Firebase to auto-create Auth users via Google.
 * Email/password registration (createUserWithEmailAndPassword) is unaffected.
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
