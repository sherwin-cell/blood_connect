import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/account_gateway.dart';

const _red = Color(0xFFC62828);
const _softRed = Color(0xFFFDECEC);
const _border = Color(0xFFEDEDED);

/// What deleting the account removes and keeps. Must match
/// blood_connect_backend/account/service.py.
const deleteAccountRemoves = [
  'Your profile, profile photo and notification settings',
  'Your ID photos, selfies and verification records',
  'Your donor application and health questionnaire',
  'Your notifications and PRC chats',
  'Your sign-in account',
];

const deleteAccountKeeps =
    'Requests still in progress are cancelled and active donation offers '
    'are withdrawn. Completed, cancelled and expired requests and recorded '
    'donations are kept as PRC service records.';

/// Maps re-authentication errors to a message for the user.
String reauthErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Incorrect password. Please try again.';
      case 'user-mismatch':
        return 'Choose the same Google account you use for Blood-Connect.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
    }
  }
  return 'We could not confirm your identity. Please try again.';
}

/// Privacy information and in-app account deletion (a Google Play
/// requirement).
class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({
    super.key,
    required this.account,
    required this.onDeleted,
  });

  final AccountGateway account;

  /// Leaves the signed-in area once the account is gone.
  final void Function(BuildContext context) onDeleted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text(
          'Privacy & Security',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _Card(
            children: const [
              ListTile(
                leading: Icon(Icons.shield_outlined, color: _red),
                title: Text(
                  'How your data is used',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'PRC staff use your details to review blood requests, '
                  'donor applications and identity verification. Donors only '
                  'see the request details they need to help. Your ID and '
                  'selfie are compared on our server, never shared with '
                  'other users.',
                ),
              ),
              ListTile(
                leading: Icon(Icons.verified_user_outlined, color: _red),
                title: Text(
                  'Account security',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Log out on shared phones. Logging out also stops '
                  'notifications for your account on this device.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Danger Zone',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          _Card(
            children: [
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined, color: _red),
                title: const Text(
                  'Delete Account',
                  style: TextStyle(color: _red, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Permanently delete your account and personal data.',
                ),
                onTap: () => runDeleteAccountFlow(
                  context,
                  account: account,
                  onDeleted: onDeleted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Warning → re-authentication → backend deletion → sign-out.
///
/// Nothing is deleted until the user confirms the warning and proves it is
/// them (password, or picking their Google account again). The backend also
/// rejects tokens from an old sign-in.
Future<void> runDeleteAccountFlow(
  BuildContext context, {
  required AccountGateway account,
  required void Function(BuildContext context) onDeleted,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  void show(String message, {bool error = true}) => messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red : Colors.green,
    ),
  );

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => const _DeleteWarningDialog(),
  );
  if (confirmed != true || !context.mounted) return;

  // Re-authenticate so the backend receives a fresh sign-in.
  try {
    switch (account.signInMethod) {
      case SignInMethod.password:
        final password = await showDialog<String>(
          context: context,
          builder: (_) => _PasswordDialog(email: account.email),
        );
        if (password == null || !context.mounted) return;
        await account.reauthenticateWithPassword(password);
      case SignInMethod.google:
        final ok = await account.reauthenticateWithGoogle();
        if (!ok) return;
      case SignInMethod.other:
        break; // the backend asks for a recent sign-in if needed
    }
  } catch (e) {
    show(reauthErrorMessage(e));
    return;
  }
  if (!context.mounted) return;

  final navigator = Navigator.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: _red),
            SizedBox(width: 20),
            Expanded(child: Text('Deleting your account...')),
          ],
        ),
      ),
    ),
  );

  final result = await account.deleteAccount();
  navigator.pop(); // progress dialog

  if (!result.deleted) {
    show(
      result.code == AccountDeletionResult.requiresRecentLogin
          ? 'For your security, please log out, log in again and retry.'
          : result.message,
    );
    return;
  }

  await account.signOutAfterDeletion();
  show('Your account has been deleted.', error: false);
  if (context.mounted) onDeleted(context);
}

class _DeleteWarningDialog extends StatefulWidget {
  const _DeleteWarningDialog();

  @override
  State<_DeleteWarningDialog> createState() => _DeleteWarningDialogState();
}

class _DeleteWarningDialogState extends State<_DeleteWarningDialog> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: _red, size: 40),
      title: const Text('Delete your account?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            for (final item in deleteAccountRemoves)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _softRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                deleteAccountKeeps,
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _understood,
              onChanged: (v) => setState(() => _understood = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: _red,
              title: const Text(
                'I understand this cannot be undone.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _understood ? () => Navigator.of(context).pop(true) : null,
          style: TextButton.styleFrom(foregroundColor: _red),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({this.email});

  final String? email;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.isEmpty) return;
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm your password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.email == null
                ? 'Enter your password to delete your account.'
                : 'Enter the password for ${widget.email} to delete your '
                      'account.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _controller.text.isEmpty ? null : _submit,
          style: TextButton.styleFrom(foregroundColor: _red),
          child: const Text('Delete Account'),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: _border),
    ),
    child: Column(children: children),
  );
}
