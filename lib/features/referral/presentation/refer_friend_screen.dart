import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'invite_someone_screen.dart';
import 'referral_invite.dart';

/// Refer a Friend: explains referrals, then opens Invite Someone to share
/// the link, or copies it directly. Opened from Information & Services.
class ReferFriendScreen extends StatelessWidget {
  const ReferFriendScreen({super.key});

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
          'Refer a Friend',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            children: [
              const _CommunityHero(),
              const SizedBox(height: 24),
              const Text(
                'Invite Friends to Join Blood-Connect!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primaryRed,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Help us build a bigger community of blood donors and save '
                'more lives in Sorsogon.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              const _StepsCard(),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const InviteSomeoneScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.share_outlined, size: 20),
                  label: const Text('Share Blood-Connect'),
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => ReferralInvite.copyLink(context),
                  icon: const Icon(Icons.link, size: 20),
                  label: const Text('Copy Invite Link'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryRed,
                    side: const BorderSide(color: AppColors.primaryRed),
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
            ],
          ),
        ),
      ),
    );
  }
}

/// Three-person cluster: a larger crimson figure flanked by two rose ones.
class _CommunityHero extends StatelessWidget {
  const _CommunityHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 110,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(60),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Icon(Icons.person, size: 40, color: Colors.red.shade200),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 22),
            child: Icon(Icons.person, size: 60, color: AppColors.primaryRed),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Icon(Icons.person, size: 40, color: Colors.red.shade200),
          ),
        ],
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  const _StepsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF2F2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          _Step(
            number: 1,
            icon: Icons.group_outlined,
            title: 'Invite',
            text: 'Share Blood-Connect with your friends.',
          ),
          SizedBox(height: 16),
          _Step(
            number: 2,
            icon: Icons.person_add_alt_1_outlined,
            title: 'They Join',
            text: 'They can register as a blood donor or blood requester.',
          ),
          SizedBox(height: 16),
          _Step(
            number: 3,
            icon: Icons.favorite_border,
            title: 'Save Lives',
            text:
                'A larger community means a faster response during blood '
                'emergencies.',
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.icon,
    required this.title,
    required this.text,
  });

  final int number;
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primaryRed, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$number. $title',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
