import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:unicons/unicons.dart';

class ExitRequestScreen extends StatefulWidget {
  const ExitRequestScreen({super.key});
  @override
  State<ExitRequestScreen> createState() => _ExitRequestScreenState();
}

class _ExitRequestScreenState extends State<ExitRequestScreen> {
  final _api         = ApiService();
  final _formKey     = GlobalKey<FormState>();
  final _reasonCtrl  = TextEditingController();
  final _detailsCtrl = TextEditingController();

  List<dynamic> _requests = [];
  bool    _loading     = true;
  bool    _submitting  = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.getExitRequests();
      if (mounted) setState(() { _requests = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = ApiService.extractError(e); _loading = false; });
    }
  }

  bool get _hasPending => _requests.any((r) =>
      (r as Map)['status'] == 'Pending' || r['status'] == 'Under Review');

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Exit Request'),
        content: const Text(
            'This will begin the exit process. Are you sure you want to continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _submitting = true);
    try {
      await _api.submitExitRequest(
        reason:  _reasonCtrl.text.trim(),
        details: _detailsCtrl.text.trim().isEmpty ? null : _detailsCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exit request submitted successfully.'),
            backgroundColor: AppColors.emeraldMid,
          ),
        );
        _reasonCtrl.clear();
        _detailsCtrl.clear();
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.extractError(e)),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: c.card, shape: BoxShape.circle,
                    border: Border.all(color: c.border),
                  ),
                  child: Icon(UniconsLine.angle_left, color: c.textPrimary, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Request Exit', style: GoogleFonts.sora(
                  fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary))),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldDeep))
                : _error != null
                    ? _ErrorView(message: _error!, onRetry: _load)
                    : RefreshIndicator(
                        color: AppColors.emeraldDeep,
                        onRefresh: _load,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Warning box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(UniconsLine.exclamation_triangle,
                              color: Colors.white, size: 22),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Exiting the SACCO will close all accounts and refund your '
                              'contributions minus any outstanding loan balances. '
                              'This action cannot be undone.',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 13, height: 1.5),
                            ),
                          ),
                        ]),
                      ),

                      const SizedBox(height: 20),

                      // Pending request cards
                      if (_requests.isNotEmpty) ...[
                        Text('Your Requests',
                            style: TextStyle(
                                color: c.textPrimary,
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 12),
                        ..._requests.map((r) =>
                            _RequestCard(r: r as Map<String, dynamic>)),
                        const SizedBox(height: 20),
                      ],

                      // Form — only if no pending request
                      if (!_hasPending) ...[
                        Text('Submit New Request',
                            style: TextStyle(
                                color: c.textPrimary,
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 16),
                        Form(
                          key: _formKey,
                          child: Column(children: [
                            TextFormField(
                              controller: _reasonCtrl,
                              style: TextStyle(color: c.textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Reason for exit *',
                                labelStyle: TextStyle(color: c.textSecondary),
                                hintText: 'e.g. Relocation, retirement...',
                                hintStyle: TextStyle(color: c.textHint),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Please provide a reason' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _detailsCtrl,
                              maxLines: 3,
                              style: TextStyle(color: c.textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Additional details (optional)',
                                labelStyle: TextStyle(color: c.textSecondary),
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _submitting ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.danger,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 56),
                                  shape: const StadiumBorder(),
                                ),
                                child: _submitting
                                    ? const SizedBox(
                                        height: 20, width: 20,
                                        child: CircularProgressIndicator(
                                            color: Colors.white, strokeWidth: 2))
                                    : Text('Submit Exit Request',
                                        style: GoogleFonts.sora(
                                            fontSize: 16, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ]),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(children: [
                            Icon(UniconsLine.hourglass, color: Colors.white, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'You have a pending exit request. '
                                'Please wait for it to be processed before submitting another.',
                                style: TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ),
                          ]),
                        ),
                      ],
                          ]),
                        ),
                      ),
          ),
        ]),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> r;
  const _RequestCard({required this.r});

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final status = r['status'] as String? ?? 'Pending';
    final Color statusColor;
    switch (status) {
      case 'Approved':    statusColor = AppColors.emeraldMid; break;
      case 'Rejected':    statusColor = AppColors.danger;   break;
      case 'Under Review': statusColor = AppColors.gold;   break;
      default:            statusColor = AppColors.gold;
    }
    final reason  = r['reason'] as String? ?? '—';
    final details = r['details'] as String?;
    final date    = r['created_at'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Exit Request',
              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(status,
                style: const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(reason, style: TextStyle(color: c.textSecondary, fontSize: 13)),
        if (details != null && details.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(details, style: TextStyle(color: c.textHint, fontSize: 12)),
        ],
        if (date != null) ...[
          const SizedBox(height: 8),
          Text('Submitted: $date',
              style: TextStyle(color: c.textHint, fontSize: 11)),
        ],
      ]),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(UniconsLine.info_circle, size: 48, color: AppColors.danger),
        const SizedBox(height: 12),
        Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textSecondary)),
        const SizedBox(height: 16),
        TextButton(
          onPressed: onRetry,
          child: const Text('Retry', style: TextStyle(color: AppColors.emeraldDeep)),
        ),
      ]),
    ),
  );
}
