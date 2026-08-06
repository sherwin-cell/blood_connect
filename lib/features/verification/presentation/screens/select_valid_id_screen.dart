import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/verification_provider.dart';
import 'capture_id_screen.dart';

class GovernmentIdOption {
  final String idKey;
  final String title;
  final String subtitle;
  final IconData icon;

  const GovernmentIdOption({
    required this.idKey,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class SelectValidIdScreen extends StatefulWidget {
  const SelectValidIdScreen({super.key});

  @override
  State<SelectValidIdScreen> createState() => _SelectValidIdScreenState();
}

class _SelectValidIdScreenState extends State<SelectValidIdScreen> {
  String? _selectedIdKey;

  final List<GovernmentIdOption> _idOptions = const [
    GovernmentIdOption(
      idKey: 'philsys',
      title: 'Philippine National ID (PhilSys)',
      subtitle: 'Physical card or ePhilID accepted',
      icon: Icons.badge_outlined,
    ),
    GovernmentIdOption(
      idKey: 'drivers_license',
      title: "Driver's License",
      subtitle: 'LTO issued photo identification card',
      icon: Icons.time_to_leave_outlined,
    ),
    GovernmentIdOption(
      idKey: 'umid',
      title: 'UMID',
      subtitle: 'Unified Multi-Purpose ID (SSS/GSIS)',
      icon: Icons.credit_card_outlined,
    ),
    GovernmentIdOption(
      idKey: 'prc',
      title: 'PRC ID',
      subtitle: 'Professional Regulation Commission ID',
      icon: Icons.workspace_premium_outlined,
    ),
  ];

  void _onContinuePressed() {
    if (_selectedIdKey == null) return;

    final provider = context.read<VerificationProvider>();

    // Persist the selected ID type so it's actually saved to Firestore.
    provider.setIdType(_selectedIdKey!);

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity Verification'),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Header Section ---
                    Text(
                      'Select a Valid Government ID',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose the government-issued ID you will submit for identity verification.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- ID Selection List ---
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _idOptions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final option = _idOptions[index];
                        final isSelected = _selectedIdKey == option.idKey;

                        return Card(
                          elevation: isSelected ? 2 : 0,
                          color: isSelected
                              ? colorScheme.primaryContainer.withOpacity(0.3)
                              : colorScheme.surfaceVariant.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.outlineVariant,
                              width: isSelected ? 2.0 : 1.0,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              setState(() {
                                _selectedIdKey = option.idKey;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  // Leading Icon
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? colorScheme.primary
                                          : colorScheme.surface,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      option.icon,
                                      color: isSelected
                                          ? colorScheme.onPrimary
                                          : colorScheme.onSurfaceVariant,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // ID Title & Subtitle
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          option.title,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.onSurface,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          option.subtitle,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Selected Indicator
                                  Radio<String>(
                                    value: option.idKey,
                                    groupValue: _selectedIdKey,
                                    activeColor: colorScheme.primary,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedIdKey = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 28),

                    // --- Requirements Container ---
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Requirements',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildRequirementItem(
                            theme,
                            'Use an original government-issued ID.',
                          ),
                          _buildRequirementItem(
                            theme,
                            'Expired IDs may be rejected.',
                          ),
                          _buildRequirementItem(
                            theme,
                            'Make sure all text is readable.',
                          ),
                          _buildRequirementItem(
                            theme,
                            'The information should match your Blood-Connect profile.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- Sticky Bottom Action ---
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _selectedIdKey != null ? _onContinuePressed : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    disabledBackgroundColor: colorScheme.onSurface.withOpacity(
                      0.12,
                    ),
                    disabledForegroundColor: colorScheme.onSurface.withOpacity(
                      0.38,
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementItem(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
