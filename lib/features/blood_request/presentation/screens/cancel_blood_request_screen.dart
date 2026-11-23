import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/notification_router.dart';
import '../widgets/request_progress_widgets.dart';

/// Reasons offered on the Cancel Request screen.
abstract final class CancellationReasons {
  static const foundDonorElsewhere =
      'Found a donor outside Blood-Connect and no longer need donor '
      'recruitment.';
  static const bloodAvailable = 'Blood is already available at the hospital.';
  static const conditionChanged =
      "The patient's condition has changed and the request is no longer "
      'needed.';
  static const duplicate = 'Duplicate request (submitted by mistake).';
  static const other = 'Other (Please specify)';

  static const all = [
    foundDonorElsewhere,
    bloodAvailable,
    conditionChanged,
    duplicate,
    other,
  ];

  static const maxDetailsLength = 200;

  /// The single `cancellationReason` string stored on the request (the
  /// owner-cancel rule allows only that field for the reason).
  static String compose(String reason, String details) {
    final extra = details.trim();
    if (reason == other) return 'Other: $extra';
    return extra.isEmpty ? reason : '$reason Additional details: $extra';
  }
}

/// Opens Activity after a cancellation: back to the dashboard (the first
/// route) and switch it to the Activity tab.
void backToActivity(BuildContext context) {
  NotificationRouter.instance.requestedTab.value = 1;
  Navigator.of(context).popUntil((route) => route.isFirst);
}

/// Screen 1: choose why the request is being cancelled, then submit.
class CancelBloodRequestScreen extends StatefulWidget {
  const CancelBloodRequestScreen({
    super.key,
    required this.reference,
    required this.cancel,
    this.onBackToActivity,
    this.now,
  });

  /// BR-... reference shown on the confirmation screen.
  final String reference;

  /// Runs the Firestore cancellation with the composed reason.
  final Future<void> Function(String reason) cancel;

  /// Test hook; defaults to [backToActivity].
  final void Function(BuildContext context)? onBackToActivity;

  /// Test hook for the "Cancelled On" time.
  final DateTime Function()? now;

  @override
  State<CancelBloodRequestScreen> createState() =>
      _CancelBloodRequestScreenState();
}

class _CancelBloodRequestScreenState extends State<CancelBloodRequestScreen> {
  final _details = TextEditingController();
  String? _reason;
  bool _submitting = false;
  bool _showDetailsError = false;

  bool get _needsDetails =>
      _reason == CancellationReasons.other && _details.text.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    _details.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) return;
    if (_needsDetails) {
      setState(() => _showDetailsError = true);
      return;
    }
    setState(() => _submitting = true);
    final details = _details.text.trim();
    try {
      await widget.cancel(CancellationReasons.compose(reason, details));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!mounted) return;
    // Replace the form so Back cannot submit it again.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RequestCancelledScreen(
          reference: widget.reference,
          reason: reason == CancellationReasons.other ? 'Other' : reason,
          details: details.isEmpty ? null : details,
          cancelledOn: (widget.now ?? DateTime.now)(),
          onBackToActivity: widget.onBackToActivity,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailsError = _showDetailsError && _needsDetails
        ? 'Please describe your reason.'
        : null;
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text(
          'Cancel Request',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: requestSoftRed,
                shape: BoxShape.circle,
              ),
              child: const Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.assignment_outlined, size: 46, color: requestRed),
                  Positioned(
                    right: 14,
                    bottom: 14,
                    child: CircleAvatar(
                      radius: 11,
                      backgroundColor: requestRed,
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Cancel Blood Request',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Please provide a reason for canceling your blood request.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 20),
          RequestCardShell(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text.rich(
                    TextSpan(
                      text: 'Cancellation Reason ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(
                          text: '*',
                          style: TextStyle(color: requestRed),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                RadioGroup<String>(
                  groupValue: _reason,
                  onChanged: (v) {
                    if (_submitting) return;
                    setState(() => _reason = v);
                  },
                  child: Column(
                    children: [
                      for (final reason in CancellationReasons.all)
                        RadioListTile<String>(
                          value: reason,
                          activeColor: requestRed,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          title: Text(
                            reason,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          RequestCardShell(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _reason == CancellationReasons.other
                      ? 'Additional Details *'
                      : 'Additional Details (Optional)',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _details,
                  enabled: !_submitting,
                  maxLength: CancellationReasons.maxDetailsLength,
                  maxLines: 4,
                  minLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Tell PRC more about why you are cancelling.',
                    errorText: detailsError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: requestRed),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _reason == null || _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: requestRed,
                foregroundColor: Colors.white,
                disabledBackgroundColor: requestRed.withValues(alpha: 0.35),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Submit Cancellation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen 2: confirmation after a successful cancellation.
class RequestCancelledScreen extends StatelessWidget {
  const RequestCancelledScreen({
    super.key,
    required this.reference,
    required this.reason,
    required this.cancelledOn,
    this.details,
    this.onBackToActivity,
  });

  final String reference;
  final String reason;
  final String? details;
  final DateTime cancelledOn;
  final void Function(BuildContext context)? onBackToActivity;

  void _back(BuildContext context) =>
      (onBackToActivity ?? backToActivity)(context);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F9F9),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2E7D32),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Request Cancelled',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your blood request has been successfully cancelled.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: requestSoftRed,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cancellation Reason',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: requestRed,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      reason,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (details != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        details!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              RequestCardShell(
                child: Column(
                  children: [
                    _SummaryRow('Request ID', Text(reference, style: _value)),
                    const Divider(height: 20),
                    _SummaryRow(
                      'Cancelled On',
                      Text(
                        DateFormat('MMM d, yyyy, h:mm a').format(cancelledOn),
                        style: _value,
                      ),
                    ),
                    const Divider(height: 20),
                    _SummaryRow(
                      'Status',
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F1F1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Cancelled',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _back(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: requestRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Back to Activity',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _value = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
      value,
    ],
  );
}
