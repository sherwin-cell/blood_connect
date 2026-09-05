import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../provider/verification_provider.dart';
import 'capture_id_screen.dart';

class AcceptedIdItem {
  final String title;
  final String subtitle;
  final IconData icon;

  const AcceptedIdItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class SelectValidIdScreen extends StatelessWidget {
  const SelectValidIdScreen({super.key});

  final List<AcceptedIdItem> _acceptedIds = const [
    AcceptedIdItem(
      title: 'Philippine National ID (PhilSys)',
      subtitle: 'Physical card or ePhilID accepted',
      icon: Icons.badge_outlined,
    ),
    AcceptedIdItem(
      title: "Driver's License",
      subtitle: 'LTO-issued photo identification card',
      icon: Icons.time_to_leave_outlined,
    ),
    AcceptedIdItem(
      title: 'UMID',
      subtitle: 'Unified Multi-Purpose ID (SSS/GSIS)',
      icon: Icons.credit_card_outlined,
    ),
    AcceptedIdItem(
      title: 'PRC ID',
      subtitle: 'Professional Regulation Commission ID',
      icon: Icons.workspace_premium_outlined,
    ),
  ];

  void _onContinuePressed(BuildContext context) {
    final provider = context.read<VerificationProvider>();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: const CaptureIdScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Submit a Valid ID',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.black87,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header Section ---
              const Text(
                'Submit a valid ID',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Prepare your valid government-issued ID for verification.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.black54,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),

              // --- Accepted IDs Title ---
              const Text(
                'Accepted Government IDs',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),

              // --- Compact List Format ---
              Expanded(
                child: ListView.separated(
                  itemCount: _acceptedIds.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 12, color: Colors.black12),
                  itemBuilder: (context, index) {
                    final item = _acceptedIds[index];

                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFEBEE),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            item.icon,
                            color: const Color(0xFFC62828),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                item.subtitle,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.black.withOpacity(0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              // --- Security Privacy Notice (Compact) ---
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.security_rounded,
                      color: Colors.blueGrey,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your identification data is handled securely and used only for verification.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // --- Sticky Bottom Action Area ---
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => _onContinuePressed(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue to ID Upload',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
