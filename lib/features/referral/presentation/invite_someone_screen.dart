import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'referral_invite.dart';

/// Invite Someone: the user's referral link with copy and share options.
/// Opened from Refer a Friend's "Share Blood-Connect" button.
class InviteSomeoneScreen extends StatelessWidget {
  const InviteSomeoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text(
          'Invite Someone',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(child: _InviteBadge()),
                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        'Your invitation helps save lives.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.primaryRed,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Share the link below with your friends and family to '
                        'join Blood-Connect.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _SectionLabel('Your Referral Link'),
                    const SizedBox(height: 8),
                    const _ReferralLinkBox(),
                    const SizedBox(height: 16),
                    const _VerificationCallout(),
                    const SizedBox(height: 24),
                    const _SectionLabel('Share via'),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _ShareOption(
                          icon: Icons.messenger_outline,
                          label: 'Messenger',
                          onTap: () =>
                              ReferralInvite.shareViaMessenger(context),
                        ),
                        _ShareOption(
                          icon: Icons.sms_outlined,
                          label: 'SMS',
                          onTap: () => ReferralInvite.shareViaSms(context),
                        ),
                        _ShareOption(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          onTap: () => ReferralInvite.shareViaEmail(context),
                        ),
                        _ShareOption(
                          icon: Icons.more_horiz,
                          label: 'More',
                          onTap: () => ReferralInvite.shareSheet(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const _NoteCard(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => ReferralInvite.shareSheet(context),
                  icon: const Icon(Icons.share_outlined, size: 20),
                  label: const Text('Share Invitation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Blush circle with two people and a blood droplet.
class _InviteBadge extends StatelessWidget {
  const _InviteBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        shape: BoxShape.circle,
      ),
      child: const Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.people_alt_outlined,
            size: 52,
            color: AppColors.primaryRed,
          ),
          Positioned(
            right: 18,
            bottom: 20,
            child: Icon(
              Icons.water_drop,
              size: 22,
              color: AppColors.primaryRed,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }
}

class _ReferralLinkBox extends StatelessWidget {
  const _ReferralLinkBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.link, color: AppColors.primaryRed, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ReferralInvite.link,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => ReferralInvite.copyLink(context),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryRed,
              backgroundColor: Colors.red.shade50,
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationCallout extends StatelessWidget {
  const _VerificationCallout();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: Colors.green.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'All new users are verified by the Philippine Red Cross before '
              'they can donate or request blood.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade900,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primaryRed, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF2F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.primaryRed, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Note: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                    text:
                        'They will need to register and complete Philippine '
                        'Red Cross verification.',
                  ),
                ],
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade800,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
