import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// The invite link and message shared by the Refer a Friend flow, plus the
/// actions that send them (copy, share sheet, Messenger, SMS, email).
abstract final class ReferralInvite {
  /// Firebase Hosting site; the Android manifest opens this host in the app.
  static const baseUrl = 'https://blood-connect-12ac2.web.app';

  static const subject = 'Join Blood-Connect';

  /// Short code from the signed-in user's uid, or null when signed out.
  static String? get referralCode {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    return (uid.length > 8 ? uid.substring(0, 8) : uid).toUpperCase();
  }

  /// `<baseUrl>/invite?ref=<code>`, or `<baseUrl>/invite` when signed out.
  static String get link {
    final code = referralCode;
    if (code == null) return '$baseUrl/invite';
    return '$baseUrl/invite?ref=${Uri.encodeQueryComponent(code)}';
  }

  static String get message =>
      'Join me on Blood-Connect! Register as a blood donor or requester and '
      'help save lives in Sorsogon. All new users are verified by the '
      'Philippine Red Cross.\n\n$link';

  static Future<void> copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    _showSnackBar(context, 'Invite link copied!');
  }

  /// Opens the native share sheet.
  static Future<void> shareSheet(BuildContext context) async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: message, subject: subject),
      );
    } catch (e) {
      if (!context.mounted) return;
      _showSnackBar(context, 'Could not open the share sheet: $e');
    }
  }

  static Future<void> shareViaMessenger(BuildContext context) => _launchOrShare(
    context,
    Uri.parse('fb-messenger://share?link=${Uri.encodeComponent(link)}'),
  );

  static Future<void> shareViaSms(BuildContext context) => _launchOrShare(
    context,
    Uri.parse('sms:?body=${Uri.encodeComponent(message)}'),
  );

  static Future<void> shareViaEmail(BuildContext context) => _launchOrShare(
    context,
    Uri.parse(
      'mailto:?subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(message)}',
    ),
  );

  /// Opens [uri] in the app that handles it; falls back to the share sheet
  /// when no app does (e.g. Messenger not installed).
  static Future<void> _launchOrShare(BuildContext context, Uri uri) async {
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (launched || !context.mounted) return;
    await shareSheet(context);
  }

  static void _showSnackBar(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}
