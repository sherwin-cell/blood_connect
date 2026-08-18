# Blood-Connect Auth Cloud Functions

Secure **Google login-only** (never auto-registers unknown Google accounts).

## Why a backend is required

Firebase client `signInWithCredential(GoogleAuthProvider…)` **creates** a new
Auth user when none exists. Checking afterward and deleting is not allowed.

These functions verify the Google identity with the Admin SDK **before** any
session is created, and only then issue a **custom token** for an existing user.

## Functions

| Name | Role |
|------|------|
| `googleLoginOnly` | Verify Google ID token → `getUserByEmail` → custom token, or reject |
| `blockGoogleAutoRegistration` | `beforeCreate` block so Google can never provision new Auth users |

## Deploy

Requires the Blaze plan and the Firebase CLI.

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

For `blockGoogleAutoRegistration`, enable **blocking functions** / Identity
Platform in the Firebase console (Authentication → Settings / Blocking functions).

If blocking functions cannot be enabled yet, still deploy `googleLoginOnly` —
the Flutter app uses that path and never calls `signInWithCredential`.
