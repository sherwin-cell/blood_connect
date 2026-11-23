/// Where a user is in identity verification. Verification order is ID first,
/// then selfie, so the stage depends on both users/{uid}.faceVerified and
/// whether id_verifications/{uid} holds a submitted ID.
enum AccountVerificationStage {
  /// No ID on file yet: upload the ID, then take the selfie.
  notVerified,

  /// ID on file, selfie not matched (or not tried) yet: selfie only.
  faceNotVerified,

  /// Face matched by the backend, or approved by PRC.
  verified;

  static AccountVerificationStage of({
    required bool faceVerified,
    required bool hasSubmittedId,
  }) {
    if (faceVerified) return AccountVerificationStage.verified;
    return hasSubmittedId
        ? AccountVerificationStage.faceNotVerified
        : AccountVerificationStage.notVerified;
  }

  /// Short status label for the banner and member card.
  String get label => switch (this) {
    AccountVerificationStage.notVerified => 'Not Verified',
    AccountVerificationStage.faceNotVerified => 'Face Not Verified',
    AccountVerificationStage.verified => 'Verified',
  };

  /// The step tapping "Verify Now" starts with.
  bool get needsIdUpload => this == AccountVerificationStage.notVerified;

  /// Banner explanation. [lastCheckFailed] is the user's
  /// faceVerificationFailed (last automatic check failed or PRC rejected).
  String bannerMessage({bool lastCheckFailed = false}) {
    switch (this) {
      case AccountVerificationStage.notVerified:
        return 'Upload a valid ID, then take a selfie to unlock blood '
            'requests and donor features.';
      case AccountVerificationStage.faceNotVerified:
        return lastCheckFailed
            ? 'Your last face check did not pass. Retry (5 attempts a day) '
                  'or wait for PRC to review your account.'
            : 'Your ID is on file. Complete your selfie check to unlock '
                  'blood requests and donor features.';
      case AccountVerificationStage.verified:
        return 'Your identity is verified.';
    }
  }

  /// Gate dialog text when a locked action is tapped.
  String gateMessage(String actionName, {bool lastCheckFailed = false}) {
    switch (this) {
      case AccountVerificationStage.notVerified:
        return 'Upload a valid ID, then take a selfie before you can '
            '$actionName.';
      case AccountVerificationStage.faceNotVerified:
        return lastCheckFailed
            ? 'Your last face check did not pass. Retry (5 attempts a day) '
                  'or wait for PRC to review your account before you can '
                  '$actionName.'
            : 'Your ID is on file. Complete your selfie check before you '
                  'can $actionName.';
      case AccountVerificationStage.verified:
        return '';
    }
  }

  /// Gate dialog / banner button text.
  String get actionLabel => switch (this) {
    AccountVerificationStage.notVerified => 'Upload Valid ID',
    AccountVerificationStage.faceNotVerified => 'Verify My Face',
    AccountVerificationStage.verified => 'Continue',
  };
}
