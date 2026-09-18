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
 *   Firebase Auth user via Google.
 *
 * ID Verification:
 *   ID verification is handled by the Flutter application and Firestore.
 *   Users submit their ID and selfie, which creates a PENDING verification.
 *   Final approval or rejection is performed ONLY by the PRC Admin.
 *
 * Deploy:
 *   cd functions && npm install
 *   firebase deploy --only functions
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { beforeUserCreated } = require("firebase-functions/v2/identity");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { OAuth2Client } = require("google-auth-library");

initializeApp();

/**
 * Web client ID used by google_sign_in (serverClientId)
 */
const GOOGLE_WEB_CLIENT_ID =
  "394558242984-d2unmof80o47siujfrkimcu6ljrlin5k.apps.googleusercontent.com";

const oauthClient = new OAuth2Client(GOOGLE_WEB_CLIENT_ID);

/**
 * Callable: Google login for EXISTING Google Auth users only.
 *
 * This function:
 * 1. Verifies the Google ID token.
 * 2. Checks whether the Firebase Auth account already exists.
 * 3. Rejects the login if the account does not exist.
 * 4. Creates a Firebase custom token for an existing account.
 *
 * It does NOT create new Firebase Auth users.
 */
exports.googleLoginOnly = onCall(
  { region: "us-central1" },
  async (request) => {
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

      console.error("Google login user lookup error:", error);

      throw new HttpsError(
        "internal",
        "Unable to verify account.",
      );
    }

    if (userRecord.disabled) {
      throw new HttpsError(
        "permission-denied",
        "This account has been disabled.",
      );
    }

    const customToken = await getAuth().createCustomToken(
      userRecord.uid,
    );

    return {
      customToken,
    };
  },
);

/**
 * Blocking function:
 *
 * Never allow Firebase Authentication to automatically create
 * a new Firebase Auth user through Google.
 *
 * Users must register their account first.
 */
exports.blockGoogleAutoRegistration = beforeUserCreated(
  { region: "us-central1" },
  (event) => {
    const credentialProvider = event.credential?.providerId;

    const providerData = event.data?.providerData || [];

    const isGoogle =
      credentialProvider === "google.com" ||
      providerData.some(
        (provider) => provider.providerId === "google.com",
      );

    if (isGoogle) {
      throw new HttpsError(
        "permission-denied",
        "Account not found. Please register first.",
      );
    }
  },
);