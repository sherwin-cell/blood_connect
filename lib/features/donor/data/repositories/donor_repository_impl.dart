import 'package:cloud_firestore/cloud_firestore.dart';
import '../../.././../core/utils/blood_compatibility.dart';

class DonorRepositoryImpl {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches active/approved blood requests compatible with the donor's blood type
  Stream<QuerySnapshot<Map<String, dynamic>>> getCompatibleRequestsStream(
    String donorBloodType,
  ) {
    final compatibleTypes = BloodCompatibility.getCompatibleRecipients(
      donorBloodType,
    );

    if (compatibleTypes.isEmpty) {
      return _firestore
          .collection('blood_requests')
          .where('status', isEqualTo: 'non-existent')
          .snapshots();
    }

    // Fixed BC-BUG-009: Query both 'pending' and 'approved' so newly created requests appear
    return _firestore
        .collection('blood_requests')
        .where('status', whereIn: ['pending', 'approved'])
        .where('bloodType', whereIn: compatibleTypes)
        .snapshots();
  }

  /// Fetches approved donors compatible with a requester's blood type (Recipient -> Donor)
  Stream<QuerySnapshot<Map<String, dynamic>>> getCompatibleDonorsStream(
    String recipientBloodType,
  ) {
    final compatibleDonorTypes =
        BloodCompatibility.getCompatibleDonorsForRecipient(recipientBloodType);

    if (compatibleDonorTypes.isEmpty) {
      return _firestore
          .collection('donors')
          .where('donorStatus', isEqualTo: 'non-existent')
          .snapshots();
    }

    return _firestore
        .collection('donors')
        .where('donorStatus', isEqualTo: 'approved')
        .where('bloodType', whereIn: compatibleDonorTypes)
        .snapshots();
  }

  /// Submits a donation offer with duplicate-offer protection
  Future<void> offerToDonate({
    required String requestId,
    required String donorId,
    required String donorName,
    required String donorContact,
    required String donorBloodType,
  }) async {
    final offersRef = _firestore
        .collection('blood_requests')
        .doc(requestId)
        .collection('offers');

    // Check if this donor already submitted an active offer for this request
    final existingOffer = await offersRef
        .where('donorId', isEqualTo: donorId)
        .where('status', whereIn: ['pending', 'accepted'])
        .get();

    if (existingOffer.docs.isNotEmpty) {
      throw Exception(
        'You have already submitted an active offer for this request.',
      );
    }

    await offersRef.add({
      'donorId': donorId,
      'donorName': donorName,
      'donorContact': donorContact,
      'donorBloodType': donorBloodType,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
