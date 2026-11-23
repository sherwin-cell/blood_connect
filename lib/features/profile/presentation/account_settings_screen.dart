import 'package:flutter/material.dart';

import '../../../core/services/push_notification_service.dart';
import '../data/account_gateway.dart';
import '../data/profile_repository.dart';
import '../domain/notification_preferences.dart';
import '../domain/user_profile_model.dart';

const _red = Color(0xFFC62828);
const _border = Color(0xFFEDEDED);

/// Notification switches and sign-in details.
///
/// Each switch is saved as soon as it changes (and switched back if the
/// save fails). The backend reads `notificationPreferences` before every
/// push; the announcements switch also (un)subscribes this device from the
/// announcements topic.
class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({
    super.key,
    required this.profile,
    required this.repository,
    required this.account,
    this.setAnnouncementsEnabled,
  });

  final UserProfile profile;
  final ProfileRepository repository;
  final AccountGateway account;

  /// Test hook; defaults to the push service's topic subscription.
  final Future<void> Function(bool enabled)? setAnnouncementsEnabled;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  late NotificationPreferences _prefs = widget.profile.notificationPreferences;
  final Set<String> _saving = {};

  Future<void> _toggle(String key, bool value) async {
    final previous = _prefs;
    final next = _prefs.copyWithKey(key, value);
    setState(() {
      _prefs = next;
      _saving.add(key);
    });
    try {
      await widget.repository.updateNotificationPreferences(
        widget.profile.uid,
        next,
      );
      if (key == NotificationPreferences.announcementsKey) {
        await (widget.setAnnouncementsEnabled ??
            PushNotificationService.instance.setAnnouncementsEnabled)(value);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _prefs = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your notification settings.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving.remove(key));
    }
  }

  Future<void> _resetPassword() async {
    try {
      await widget.account.sendPasswordReset();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'We sent a password reset link to ${widget.account.email}.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send the reset email. Try again later.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final method = widget.account.signInMethod;
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text(
          'Account Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const _SectionTitle('Notification Settings'),
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Choose which push notifications you receive. Everything still '
              'appears in your notification list, and verification results '
              'are always sent.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
          _Card(
            children: [
              for (final option in notificationPreferenceOptions)
                SwitchListTile(
                  key: ValueKey('pref-${option.key}'),
                  value: _prefs.valueOf(option.key),
                  onChanged: _saving.contains(option.key)
                      ? null
                      : (v) => _toggle(option.key, v),
                  activeThumbColor: _red,
                  title: Text(
                    option.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(option.subtitle),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Account'),
          _Card(
            children: [
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                subtitle: Text(widget.account.email ?? widget.profile.email),
              ),
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Sign-in method'),
                subtitle: Text(switch (method) {
                  SignInMethod.password => 'Email and password',
                  SignInMethod.google => 'Google',
                  SignInMethod.other => 'Other',
                }),
              ),
              if (method == SignInMethod.password)
                ListTile(
                  leading: const Icon(Icons.lock_reset, color: _red),
                  title: const Text('Change password'),
                  subtitle: const Text('Send a password reset link'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _resetPassword,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    ),
  );
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
