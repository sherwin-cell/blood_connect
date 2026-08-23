import 'package:flutter/material.dart';
import '../../../profile/presentation/complete_profile_screen.dart';

class HistoryTabView extends StatelessWidget {
  final VoidCallback onSignOut;

  const HistoryTabView({super.key, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Edit Profile'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CompleteProfileScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: onSignOut,
          ),
        ],
      ),
    );
  }
}
