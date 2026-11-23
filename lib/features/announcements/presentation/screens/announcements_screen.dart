import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Announcements (Item 14) is still under development: PRC cannot publish
/// announcements yet, so this screen only says so. The original Firestore
/// implementation is kept, commented out, below.
class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text(
          'Announcements',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.campaign_outlined,
                  size: 36,
                  color: AppColors.primaryRed,
                ),
              ),
              const SizedBox(height: 16),
              const UnderDevelopmentBadge(),
              const SizedBox(height: 12),
              const Text(
                'Announcements are coming soon',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'PRC-Sorsogon advisories, blood drives and donation '
                'campaigns will appear here once this feature is finished.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small amber "Under development" label.
class UnderDevelopmentBadge extends StatelessWidget {
  const UnderDevelopmentBadge({super.key, this.compact = false});

  /// Shows "Soon" instead of the full label (for small tiles).
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 5 : 10,
      vertical: compact ? 1 : 4,
    ),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF0C2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      compact ? 'Soon' : 'Under development',
      style: TextStyle(
        fontSize: compact ? 8 : 11,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF8A5A00),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Original implementation, kept for when Announcements is built.
// ---------------------------------------------------------------------------
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import '../../../../core/theme/app_theme.dart';

// class AnnouncementsScreen extends StatelessWidget {
//   const AnnouncementsScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         title: const Text(
//           'Announcements & Advisories',
//           style: TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//             fontSize: 16,
//           ),
//         ),
//         backgroundColor: AppColors.primaryRed,
//         iconTheme: const IconThemeData(color: Colors.white),
//       ),
//       body: StreamBuilder<QuerySnapshot>(
//         stream: FirebaseFirestore.instance
//             .collection('announcements')
//             .orderBy('createdAt', descending: true)
//             .snapshots(),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(
//               child: CircularProgressIndicator(color: AppColors.primaryRed),
//             );
//           }

//           if (snapshot.hasError) {
//             return Center(
//               child: Text('Error loading announcements: ${snapshot.error}'),
//             );
//           }

//           final docs = snapshot.data?.docs ?? [];

//           if (docs.isEmpty) {
//             return const Center(
//               child: Text(
//                 'No announcements available right now.',
//                 style: TextStyle(color: Colors.grey, fontSize: 14),
//               ),
//             );
//           }

//           return ListView.builder(
//             padding: const EdgeInsets.all(16.0),
//             itemCount: docs.length,
//             itemBuilder: (context, index) {
//               final data = docs[index].data() as Map<String, dynamic>;
//               final title = data['title'] ?? 'Untitled Advisory';
//               final content = data['content'] ?? '';
//               final timestamp = data['createdAt'] as Timestamp?;
//               final dateStr = timestamp != null
//                   ? timestamp.toDate().toLocal().toString().split(' ')[0]
//                   : '';

//               return Container(
//                 margin: const EdgeInsets.only(bottom: 12),
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(14),
//                   border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.grey.withValues(alpha: 0.05),
//                       blurRadius: 4,
//                       offset: const Offset(0, 2),
//                     ),
//                   ],
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Expanded(
//                           child: Text(
//                             title,
//                             style: const TextStyle(
//                               fontWeight: FontWeight.bold,
//                               fontSize: 15,
//                               color: Colors.black87,
//                             ),
//                           ),
//                         ),
//                         if (dateStr.isNotEmpty)
//                           Text(
//                             dateStr,
//                             style: TextStyle(
//                               fontSize: 11,
//                               color: Colors.grey.shade400,
//                             ),
//                           ),
//                       ],
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       content,
//                       style: TextStyle(
//                         fontSize: 13,
//                         color: Colors.grey.shade700,
//                         height: 1.4,
//                       ),
//                     ),
//                   ],
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }
