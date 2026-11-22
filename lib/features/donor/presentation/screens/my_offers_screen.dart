import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../dashboard/presentation/widgets/my_offers_section.dart';

/// Full-screen "My donation offers", opened from offer notifications.
class MyOffersScreen extends StatelessWidget {
  const MyOffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'My donation offers',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: user == null
          ? const Center(child: Text('Please sign in to view your offers.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                MyOffersSection(donorId: user.uid, showWhenEmpty: true),
              ],
            ),
    );
  }
}
