import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class VerificationService {
  // Use http://10.0.2.2:8000 for Android Emulator
  // Use http://127.0.0.1:8000 for iOS Simulator
  static const String baseUrl = "http://10.0.2.2:8000";

  /// Sends captured ID and selfie data to the local FastAPI backend
  static Future<Map<String, dynamic>> sendVerificationData({
    required String userId,
    required String idImageUrl,
    required String selfieImageUrl,
    required String croppedIdFaceBase64,
    required String selfieBase64,
    required bool livenessPassed,
  }) async {
    final Uri url = Uri.parse("$baseUrl/api/verify");

    try {
      // 1. Get the current user's Firebase ID token for secure backend authorization
      final User? currentUser = FirebaseAuth.instance.currentUser;
      final String? idToken = await currentUser?.getIdToken();

      // 2. Prepare request payload
      final Map<String, dynamic> requestBody = {
        "userId": userId,
        "idImageUrl": idImageUrl,
        "selfieImageUrl": selfieImageUrl,
        "croppedIdFaceBase64": croppedIdFaceBase64,
        "selfieBase64": selfieBase64,
        "livenessPassed": livenessPassed,
      };

      // 3. Send HTTP POST request
      final http.Response response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          if (idToken != null) "Authorization": "Bearer $idToken",
        },
        body: jsonEncode(requestBody),
      );

      // 4. Handle response
      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"success": true, "data": responseData};
      } else {
        return {
          "success": false,
          "error": responseData["detail"] ?? "Verification failed on server.",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "error": "Failed to connect to local server: $e",
      };
    }
  }
}
