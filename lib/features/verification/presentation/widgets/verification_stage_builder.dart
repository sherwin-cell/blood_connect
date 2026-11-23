import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/firestore_service.dart';
import '../../../profile/domain/user_profile_model.dart';
import '../../domain/entities/account_verification_stage.dart';

/// Rebuilds with the user's [AccountVerificationStage], combining
/// users/{uid}.faceVerified (from [profile]) with a live read of
/// id_verifications/{uid}.
///
/// Verified users skip the ID read entirely. Until the ID read answers (or
/// if it fails), the user counts as having no ID on file, which sends them
/// to the ID step; that step re-checks before uploading anything.
class VerificationStageBuilder extends StatefulWidget {
  const VerificationStageBuilder({
    super.key,
    required this.profile,
    required this.builder,
    this.idSubmitted,
  });

  final UserProfile? profile;
  final Widget Function(BuildContext context, AccountVerificationStage stage)
  builder;

  /// Test hook; defaults to FirestoreService.watchIdSubmitted.
  final Stream<bool>? idSubmitted;

  @override
  State<VerificationStageBuilder> createState() =>
      _VerificationStageBuilderState();
}

class _VerificationStageBuilderState extends State<VerificationStageBuilder> {
  Stream<bool>? _stream;
  String? _uid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveStream();
  }

  @override
  void didUpdateWidget(VerificationStageBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resolveStream();
  }

  /// One Firestore listener per user, not per rebuild.
  void _resolveStream() {
    if (widget.idSubmitted != null) {
      _stream = widget.idSubmitted;
      return;
    }
    final uid = widget.profile?.uid ?? '';
    if (uid == _uid) return;
    _uid = uid;
    _stream = uid.isEmpty
        ? Stream<bool>.value(false)
        : context.read<FirestoreService>().watchIdSubmitted(uid);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.profile?.faceVerified == true) {
      return widget.builder(context, AccountVerificationStage.verified);
    }
    return StreamBuilder<bool>(
      stream: _stream,
      builder: (context, snapshot) => widget.builder(
        context,
        AccountVerificationStage.of(
          faceVerified: false,
          hasSubmittedId: snapshot.data ?? false,
        ),
      ),
    );
  }
}
