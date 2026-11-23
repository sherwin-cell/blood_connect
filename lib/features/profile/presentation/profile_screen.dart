import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_gate.dart';
import '../../help/presentation/help_guides_screen.dart';
import '../../verification/domain/entities/account_verification_stage.dart';
import '../../verification/presentation/widgets/verification_stage_builder.dart';
import '../data/account_gateway.dart';
import '../data/profile_repository.dart';
import '../domain/user_profile_model.dart';
import 'account_settings_screen.dart';
import 'edit_profile_screen.dart';
import 'privacy_security_screen.dart';

const profileRed = Color(0xFFC62828);
const profileSoftRed = Color(0xFFFDECEC);
const profileBorder = Color(0xFFEDEDED);

/// Leaves the signed-in area after logging out or deleting the account.
void goToSignIn(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const AuthGate()),
    (_) => false,
  );
}

/// The user's profile: header card, personal information and settings.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.uid,
    this.repository,
    this.account,
    this.idSubmitted,
    this.onSignedOut,
  });

  /// Defaults to the signed-in user.
  final String? uid;
  final ProfileRepository? repository;
  final AccountGateway? account;

  /// Test hook for the verification badge (see VerificationStageBuilder).
  final Stream<bool>? idSubmitted;

  /// Called after logging out or deleting the account; defaults to the
  /// sign-in screen.
  final void Function(BuildContext context)? onSignedOut;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileRepository _repository =
      widget.repository ?? FirestoreProfileRepository();
  late final AccountGateway _account =
      widget.account ?? FirebaseAccountGateway();
  late final String? _uid =
      widget.uid ?? FirebaseAuth.instance.currentUser?.uid;
  late final Stream<UserProfile?>? _profile = _uid == null
      ? null
      : _repository.watch(_uid);

  void _signedOut() => (widget.onSignedOut ?? goToSignIn)(context);

  Future<void> _edit(UserProfile profile) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          EditProfileScreen(profile: profile, repository: _repository),
    ),
  );

  Future<void> _confirmLogOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: profileRed),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _account.logOut();
      if (mounted) _signedOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not log out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: _profile == null
          ? const Center(child: Text('Please sign in to view your profile.'))
          : StreamBuilder<UserProfile?>(
              stream: _profile,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Could not load your profile.'),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: profileRed),
                  );
                }
                final profile = snapshot.data;
                if (profile == null) {
                  return const Center(child: Text('Profile not found.'));
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    _HeaderCard(
                      profile: profile,
                      idSubmitted: widget.idSubmitted,
                      onAvatarTap: () => _edit(profile),
                    ),
                    const SizedBox(height: 16),
                    _PersonalInfoCard(
                      profile: profile,
                      onEdit: () => _edit(profile),
                    ),
                    const SizedBox(height: 16),
                    _MenuCard(
                      children: [
                        _MenuTile(
                          icon: Icons.settings_outlined,
                          title: 'Account Settings',
                          subtitle: 'Notifications and sign-in',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AccountSettingsScreen(
                                profile: profile,
                                repository: _repository,
                                account: _account,
                              ),
                            ),
                          ),
                        ),
                        _MenuTile(
                          icon: Icons.lock_outline,
                          title: 'Privacy & Security',
                          subtitle: 'Your data and account deletion',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PrivacySecurityScreen(
                                account: _account,
                                onDeleted: (ctx) =>
                                    (widget.onSignedOut ?? goToSignIn)(ctx),
                              ),
                            ),
                          ),
                        ),
                        _MenuTile(
                          icon: Icons.help_outline,
                          title: 'Help & Support',
                          subtitle: 'FAQs and guides',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const HelpGuidesScreen(),
                            ),
                          ),
                        ),
                        _MenuTile(
                          icon: Icons.logout,
                          title: 'Log Out',
                          destructive: true,
                          onTap: _confirmLogOut,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.profile,
    required this.onAvatarTap,
    this.idSubmitted,
  });

  final UserProfile profile;
  final VoidCallback onAvatarTap;
  final Stream<bool>? idSubmitted;

  @override
  Widget build(BuildContext context) {
    final avatar = profile.avatarUrl;
    final name = profile.fullName.trim().isEmpty
        ? 'BLOOD-CONNECT MEMBER'
        : profile.fullName.trim().toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryRed, AppColors.deepRed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Semantics(
            button: true,
            label: 'Change profile picture',
            child: GestureDetector(
              onTap: onAvatarTap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: profileSoftRed,
                      backgroundImage: avatar == null
                          ? null
                          : NetworkImage(avatar),
                      child: avatar == null
                          ? const Icon(
                              Icons.person,
                              size: 48,
                              color: profileRed,
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: profileBorder),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: profileRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            profile.memberCode,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 10),
          VerificationStageBuilder(
            profile: profile,
            idSubmitted: idSubmitted,
            builder: (context, stage) => _VerificationBadge(stage: stage),
          ),
        ],
      ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({required this.stage});

  final AccountVerificationStage stage;

  @override
  Widget build(BuildContext context) {
    final verified = stage == AccountVerificationStage.verified;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: verified ? const Color(0xFFE8F5E9) : Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.verified : Icons.error_outline,
            size: 16,
            color: verified ? const Color(0xFF2E7D32) : profileRed,
          ),
          const SizedBox(width: 6),
          Text(
            verified ? 'Verified Account' : stage.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: verified ? const Color(0xFF2E7D32) : profileRed,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalInfoCard extends StatelessWidget {
  const _PersonalInfoCard({required this.profile, required this.onEdit});

  final UserProfile profile;
  final VoidCallback onEdit;

  static String _or(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Not set' : value.trim();

  @override
  Widget build(BuildContext context) {
    final birth = profile.birthDate;
    final rows = <(IconData, String, String)>[
      (Icons.person_outline, 'Full Name', _or(profile.fullName)),
      (
        Icons.cake_outlined,
        'Date of Birth',
        birth == null ? 'Not set' : DateFormat('MMMM d, yyyy').format(birth),
      ),
      (Icons.wc_outlined, 'Gender', _or(profile.gender)),
      (Icons.flag_outlined, 'Nationality', _or(profile.nationality)),
      (Icons.phone_outlined, 'Contact Number', _or(profile.phoneNumber)),
      (Icons.email_outlined, 'Email Address', _or(profile.email)),
      (Icons.home_outlined, 'Address', _or(profile.formattedAddress)),
    ];
    return _MenuCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Personal Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              onPressed: onEdit,
              style: TextButton.styleFrom(foregroundColor: profileRed),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
          ],
        ),
        for (final (icon, label, value) in rows)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6, right: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: Colors.black45),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: profileBorder),
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? profileRed : Colors.black87;
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: profileSoftRed,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: profileRed, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: color),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: destructive
          ? null
          : const Icon(Icons.chevron_right, color: Colors.black38),
    );
  }
}
