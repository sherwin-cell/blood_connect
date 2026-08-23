import 'package:flutter/material.dart';

class ActivityTabView extends StatelessWidget {
  const ActivityTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Activity Screen',
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }
}
