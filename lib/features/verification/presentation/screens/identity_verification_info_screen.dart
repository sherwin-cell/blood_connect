import 'package:flutter/material.dart';

import '../identity_verification_flow.dart';

const _red = Color(0xFFC62828);
const _redSoft = Color(0xFFFFEBEE);
const _ink = Color(0xFF1F1F1F);
const _muted = Color(0xFF6B6B6B);

class IdentityVerificationInfoScreen extends StatelessWidget {
  const IdentityVerificationInfoScreen({super.key});

  static const _steps = [
    _Step(
      Icons.badge_outlined,
      'Choose a valid ID',
      'Select the government-issued ID type you will upload',
    ),
    _Step(
      Icons.credit_card_outlined,
      'Upload front and back',
      'Capture both sides clearly. Skipped if your ID is already on file',
    ),
    _Step(
      Icons.face_retouching_natural_outlined,
      'Take a selfie',
      'Follow the live face steps in good light',
    ),
    _Step(
      Icons.verified_outlined,
      'Get verified',
      'Your selfie is matched to your ID photo. You have 5 tries a day',
    ),
  ];

  static const _tips = [
    (Icons.wb_sunny_outlined, 'Find a well-lit place'),
    (Icons.badge_outlined, 'Have your valid ID with you'),
    (Icons.face_outlined, 'Remove hats, masks and sunglasses'),
  ];

  Future<void> _continue(BuildContext context) async {
    final navigator = Navigator.of(context);
    final thisRoute = ModalRoute.of(context);
    // ID first, then selfie.
    await IdentityVerificationFlow.start(context);
    // Remove only this intro screen, wherever it now sits.
    // start() can return while the selfie camera is open
    // (the guide replaces itself with it), so popping the
    // top route here would close the camera.
    if (navigator.mounted && thisRoute != null && thisRoute.isActive) {
      navigator.removeRoute(thisRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Identity Verification',
          style: TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: _ink, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
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
                  const _SectionLabel('HOW IT WORKS'),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _steps.length; i++)
                    _StepTile(
                      number: i + 1,
                      step: _steps[i],
                      isLast: i == _steps.length - 1,
                    ),
                  const SizedBox(height: 20),
                  const _SectionLabel('BEFORE YOU START'),
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
                        for (final (icon, text) in _tips)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(
                              children: [
                                Icon(icon, size: 18, color: _red),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    text,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: _ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline, size: 16, color: _muted),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your ID and selfie are only used to verify your '
                          'identity for Blood-Connect.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: _muted,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => _continue(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
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
                            'Continue',
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
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.schedule, size: 13, color: _muted),
                      SizedBox(width: 4),
                      Text(
                        'Takes about a minute to complete',
                        style: TextStyle(fontSize: 11, color: _muted),
                      ),
                    ],
                  ),
                ],
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
          colors: [_redSoft, Color(0xFFFFF7F7)],
        ),
        border: Border.all(color: const Color(0xFFF8D7D7)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _red.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Verify your identity',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Upload a valid ID first, then take a selfie. We match your '
            'face to your ID photo.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _Chip(Icons.schedule, '~1 minute'),
              _Chip(Icons.shield_outlined, 'Keeps donors safe'),
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
          Icon(icon, size: 13, color: _red),
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
                        color: _redSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(step.icon, color: _red, size: 20),
                    ),
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 17,
                        height: 17,
                        decoration: BoxDecoration(
                          color: _red,
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
                        color: const Color(0xFFF3C4C4),
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
