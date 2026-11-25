import 'package:flutter/material.dart';

import '../../../help/presentation/help_guides_screen.dart';
import 'apply_donor_step1_screen.dart';

const _green = Color(0xFF2E7D32);
const _greenSoft = Color(0xFFE8F5E9);
const _greenLine = Color(0xFFC8E6C9);
const _ink = Color(0xFF1F1F1F);
const _muted = Color(0xFF6B6B6B);

/// Intro to the donor application: the four steps (matching
/// [DonorStepIndicator]) and the basic eligibility requirements.
class ApplyDonorWelcomeScreen extends StatelessWidget {
  const ApplyDonorWelcomeScreen({super.key});

  static const _steps = [
    _Step(
      Icons.person_outline,
      'Personal Information',
      'Your details, address and contact info. Your profile fills most of '
          'it in.',
    ),
    _Step(
      Icons.bloodtype_outlined,
      'Blood Type & History',
      'Your blood type and any previous donations',
    ),
    _Step(
      Icons.health_and_safety_outlined,
      'Health Screening',
      'A short health questionnaire for your safety',
    ),
    _Step(
      Icons.fact_check_outlined,
      'Review & Submit',
      'Check your answers and send them to PRC for review',
    ),
  ];

  /// From Help & Guides > Eligibility.
  static const _eligibility = [
    (Icons.cake_outlined, '16 to 65 years old', '16–17 need guardian consent'),
    (Icons.monitor_weight_outlined, 'At least 50 kg', null),
    (Icons.favorite_border, 'In good health', 'On the day you donate'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: _ink),
        title: const Text(
          'Become a Blood Donor',
          style: TextStyle(
            color: _ink,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: const [HelpButton(section: HelpSectionTitles.eligibility)],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                children: [
                  const _Hero(),
                  const SizedBox(height: 24),
                  const _SectionLabel('WHAT TO EXPECT · 4 QUICK STEPS'),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _steps.length; i++)
                    _StepTile(
                      number: i + 1,
                      step: _steps[i],
                      isLast: i == _steps.length - 1,
                    ),
                  const SizedBox(height: 20),
                  const _SectionLabel('CAN I DONATE?'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        for (final (icon, title, note) in _eligibility)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Icon(icon, size: 18, color: _green),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _ink,
                                    ),
                                  ),
                                ),
                                if (note != null)
                                  Text(
                                    note,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: _muted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _Note(
                    Icons.medical_services_outlined,
                    'PRC makes the final decision during the medical '
                    'screening before you donate.',
                  ),
                  const SizedBox(height: 8),
                  const _Note(
                    Icons.lock_outline,
                    'Requesters never see your name. They only see an '
                    'anonymous donor code once PRC confirms you.',
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ApplyDonorStep1Screen(),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
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

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_greenSoft, Color(0xFFF6FBF6)],
        ),
        border: Border.all(color: _greenLine),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _green,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _green.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.volunteer_activism_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Give Blood, Save Lives',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Register as a donor with the Philippine Red Cross – Sorsogon '
            'Chapter and get matched with verified requests for your blood '
            'type.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _Chip(Icons.verified_outlined, 'PRC reviewed'),
              _Chip(Icons.bloodtype_outlined, 'Matched by blood type'),
              _Chip(Icons.lock_outline, 'Anonymous'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _green),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _ink,
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
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
        color: _muted,
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11.5, color: _muted, height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _Step {
  const _Step(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.number,
    required this.step,
    required this.isLast,
  });

  final int number;
  final _Step step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: _greenSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(step.icon, color: _green, size: 20),
                    ),
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 17,
                        height: 17,
                        decoration: BoxDecoration(
                          color: _green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$number',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: _greenLine,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 2, bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    step.subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
