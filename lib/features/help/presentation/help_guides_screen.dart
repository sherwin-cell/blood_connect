import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// One question and its answer.
class HelpTopic {
  const HelpTopic(this.question, this.answer);

  final String question;
  final String answer;
}

/// A group of related questions.
class HelpSection {
  const HelpSection(this.title, this.icon, this.topics);

  final String title;
  final IconData icon;
  final List<HelpTopic> topics;
}

/// Static FAQ content. Keep it in line with how the app actually behaves.
const helpSections = <HelpSection>[
  HelpSection('Eligibility', Icons.favorite_border, [
    HelpTopic(
      'Who can donate blood?',
      'In general, donors must be 16 to 65 years old (16 and 17 year olds '
          'need a parent\'s or guardian\'s consent), weigh at least 50 kg, '
          'and be in good health on the day of donation. The Philippine Red '
          'Cross (PRC) makes the final decision during the medical screening '
          'before you donate.',
    ),
    HelpTopic(
      'How often can I donate?',
      'Whole-blood donors usually wait at least 56 days (8 weeks) between '
          'donations. After each donation PRC records your next eligible '
          'date; you can see it in History > Donation. PRC may set a longer '
          'interval, and the app follows the date PRC sets.',
    ),
    HelpTopic(
      'Can I donate to any blood request?',
      'Blood-Connect matches donors to requests with exactly the same blood '
          'type (for example, A+ to A+). You will only be able to offer on '
          'requests that match your blood type.',
    ),
    HelpTopic(
      'What can stop me from donating today?',
      'Common reasons include a recent illness, low hemoglobin, recent '
          'tattoos or piercings, some medications, and not enough time since '
          'your last donation. Answer the donor questionnaire honestly; PRC '
          'staff will advise you during screening.',
    ),
  ]),
  HelpSection('How to Donate', Icons.volunteer_activism_outlined, [
    HelpTopic(
      'How do I become a donor?',
      '1. Verify your account (valid ID, then a selfie).\n'
          '2. On the Home tab, tap Apply as Blood Donor and complete the steps '
          'and health questionnaire.\n'
          '3. PRC reviews your application and schedules your screening.\n'
          '4. Once PRC approves you, you can offer to help with matching '
          'requests.',
    ),
    HelpTopic(
      'How do I offer to help with a request?',
      'Open a matching request from Blood Requester in the Matching Center '
          'or from Urgent Requests, read the medical eligibility notice, and '
          'confirm your offer. PRC reviews offers and confirms the donors who '
          'will donate. You can follow your offers in the Activity tab and '
          'withdraw one while PRC has not completed it.',
    ),
    HelpTopic(
      'What happens after I donate?',
      'PRC marks your offer as donated and records your next eligible date. '
          'The donation then appears in History > Donation with your total '
          'completed donations.',
    ),
  ]),
  HelpSection('Requesting Blood', Icons.bloodtype_outlined, [
    HelpTopic(
      'How do I request blood?',
      'Verify your account, then tap Apply for Blood Request on the Home '
          'tab and fill in the patient, blood and hospital details. PRC '
          'reviews every request before donors can see it. You can have one '
          'request in progress at a time.',
    ),
    HelpTopic(
      'Why did my request expire?',
      'Open requests close automatically when their needed-by date has '
          'passed or 7 days after they were created, whichever comes first. '
          'You will get a notification; submit a new request if blood is '
          'still needed.',
    ),
    HelpTopic(
      'Where can I see my old requests?',
      'Requests that were fulfilled, cancelled, expired or rejected are in '
          'History > Blood Request. Tap a request to see its details.',
    ),
  ]),
  HelpSection('Account Verification', Icons.verified_user_outlined, [
    HelpTopic(
      'Why do I need to verify my account?',
      'Verification protects donors and patients from fake requests and '
          'accounts. Requesting blood and donor features unlock once you are '
          'verified.',
    ),
    HelpTopic(
      'How does verification work?',
      'First upload a photo of a valid government ID. Then take a selfie. '
          'Our server compares your selfie with the photo on your ID. No '
          'face-matching happens on your phone.',
    ),
    HelpTopic(
      'My selfie did not match. What now?',
      'Retake it facing the camera in good light, without glasses or a '
          'mask. You have 5 attempts per day. Selfies that do not match are '
          'kept so PRC can review your account and approve it manually.',
    ),
    HelpTopic(
      'What does "Face Not Verified" mean?',
      'Your ID is on file but your selfie has not been verified yet. Tap '
          'Verify Now on the Home tab to take your selfie.',
    ),
  ]),
  HelpSection('Privacy & Support', Icons.support_agent_outlined, [
    HelpTopic(
      'Who can see my information?',
      'PRC staff can see the details you submit so they can review '
          'requests, donors and verification. Donors see only the request '
          'details they need to help.',
    ),
    HelpTopic(
      'How do I contact PRC?',
      'Use Chat with PRC under Information & Services on the Home tab.',
    ),
  ]),
];

/// Help & Guides: an FAQ about eligibility, donating, requesting blood and
/// verification. Opened from Information & Services and the profile menu.
/// Section titles that other screens open Help & Guides at.
abstract final class HelpSectionTitles {
  static const eligibility = 'Eligibility';
  static const requestingBlood = 'Requesting Blood';
}

/// The "?" button on form screens: opens Help & Guides with [section]
/// shown first.
class HelpButton extends StatelessWidget {
  const HelpButton({super.key, required this.section});

  final String section;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Help',
    icon: const Icon(Icons.help_outline),
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HelpGuidesScreen(initialSection: section),
      ),
    ),
  );
}

class HelpGuidesScreen extends StatefulWidget {
  const HelpGuidesScreen({super.key, this.initialSection});

  /// Title of the section to show first, e.g. from a form's "?" button.
  final String? initialSection;

  @override
  State<HelpGuidesScreen> createState() => _HelpGuidesScreenState();
}

class _HelpGuidesScreenState extends State<HelpGuidesScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final query = _search.trim().toLowerCase();
    final ordered = [
      ...helpSections.where((s) => s.title == widget.initialSection),
      ...helpSections.where((s) => s.title != widget.initialSection),
    ];
    final sections = [
      for (final s in ordered)
        if (query.isEmpty)
          s
        else if (s.topics.any((t) => _matches(t, query)))
          HelpSection(s.title, s.icon, [
            for (final t in s.topics)
              if (_matches(t, query)) t,
          ]),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text('Help & Guides'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const Text(
            'Answers about donating, requesting blood and verifying your '
            'account.',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search help topics',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFEDEDED)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFEDEDED)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (sections.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'No help topics match your search.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ),
          for (final section in sections) ...[
            Row(
              children: [
                Icon(section.icon, size: 20, color: AppColors.primaryRed),
                const SizedBox(width: 8),
                Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFEDEDED)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final topic in section.topics)
                    Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        // Open matches while searching.
                        key: ValueKey('${topic.question}|${query.isNotEmpty}'),
                        initiallyExpanded: query.isNotEmpty,
                        iconColor: AppColors.primaryRed,
                        title: Text(
                          topic.question,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        expandedAlignment: Alignment.centerLeft,
                        children: [
                          Text(
                            topic.answer,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  static bool _matches(HelpTopic t, String q) =>
      t.question.toLowerCase().contains(q) ||
      t.answer.toLowerCase().contains(q);
}
