import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/kyc_document.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/step_progress.dart';
import 'face_scan_screen.dart';
import 'selfie_intro_screen.dart';
import 'package:unicons/unicons.dart';

const _docTypes = [
  'National ID', 'Driving License', 'Staff ID Card',
];

// Documents that require both a front AND back photo
const _twoSided = {'National ID', 'Driving License'};

// ── Main KYC Screen ───────────────────────────────────────────────────────────

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});
  @override State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _api     = ApiService();
  final _dateFmt = DateFormat('dd MMM yyyy');

  String  _kycStatus     = 'Unverified';
  String? _kycVerifiedAt;
  bool    _hasSelfie     = false;
  String? _selfieStatus;
  bool    _kycLocked     = false;
  String? _demotionReason;
  String? _reviewDueAt;
  List<KycDocument> _docs = [];
  bool    _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getKycStatus();
      setState(() {
        _kycStatus      = data['kyc_status'] as String? ?? 'Unverified';
        _kycVerifiedAt  = data['kyc_verified_at'] as String?;
        _hasSelfie      = data['has_selfie'] as bool? ?? false;
        _selfieStatus   = data['selfie_status'] as String?;
        _kycLocked      = data['kyc_locked'] as bool? ?? false;
        _demotionReason = data['demotion_reason'] as String?;
        _reviewDueAt    = data['kyc_review_due_at'] as String?;
        _docs = (data['documents'] as List<dynamic>)
            .where((e) => (e as Map<String, dynamic>)['document_type'] != 'Selfie')
            .map((e) => KycDocument.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      setState(() => _error = ApiService.extractError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteDoc(KycDocument doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        return AlertDialog(
          backgroundColor: c.card,
          title: Text('Remove Document', style: TextStyle(color: c.textPrimary)),
          content: Text('Remove "${doc.documentType}"?',
              style: TextStyle(color: c.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: TextStyle(color: c.textSecondary))),
            TextButton(onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Remove',
                    style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700))),
          ],
        );
      },
    ) ?? false;
    if (!ok) return;
    try {
      await _api.deleteKycDocument(doc.id);
      _load();
    } catch (e) {
      if (mounted) AppDialogs.handleActionError(context, e,
          accessDeniedMessage: 'You don\'t have permission to remove this document.');
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
  );

  Future<void> _showUploadSheet() async {
    // Remember whether this is the member's first document — if so, we flow
    // straight into the facial scan afterwards so KYC feels like one step.
    final wasFirstDoc = _docs.isEmpty;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _UploadSheet(onUploaded: () => Navigator.pop(context)),
    );
    if (!mounted) return;
    await _load();
    // Continue straight into the liveness check once the first identity
    // document is in place and the selfie is still outstanding. Adding further
    // documents later won't re-trigger this.
    if (wasFirstDoc && _hasIdDoc && !_hasSelfie && mounted) {
      await _goToSelfie();
    }
  }

  Future<void> _goToSelfie() async {
    // Explicit consent step first — the camera must never open without warning.
    final started = await SelfieIntroScreen.show(context);
    if (!started || !mounted) return;
    final file = await FaceScanScreen.open(context);
    if (file == null || !mounted) return;
    setState(() => _loading = true);
    try {
      // Bind this upload to a fresh server-issued capture challenge (single-use,
      // ~120s). Fetched immediately before upload so it can't be replayed.
      final nonce = await _api.getSelfieChallenge();
      await _api.uploadKycSelfie(file, nonce);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Facial scan submitted successfully.'),
          backgroundColor: AppColors.emeraldMid,
        ));
      }
      _load();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) _snack(ApiService.extractError(e));
    }
  }

  bool get _hasIdDoc => _docs.isNotEmpty;

  // Upload steps are hidden when already verified, or when the account is locked
  // for KYC (server returns 423 on upload; reflect that in the UI too).
  bool get _showUploadFlow => _kycStatus != 'Verified' && !_kycLocked;

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
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('IDENTITY', style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
                const SizedBox(height: 2),
                Text('KYC verification', style: GoogleFonts.sora(
                    fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary)),
              ])),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldDeep))
                : _error != null
                    ? _ErrorView(message: _error!, onRetry: _load)
                    : RefreshIndicator(
                        color: AppColors.emeraldDeep,
                        backgroundColor: c.card,
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          children: [
                      _StatusBanner(
                        status: _kycStatus,
                        verifiedAt: _kycVerifiedAt,
                        dateFmt: _dateFmt,
                        locked: _kycLocked,
                        demotionReason: _demotionReason,
                        reviewDueAt: _reviewDueAt,
                      ),
                      const SizedBox(height: 20),

                      if (_showUploadFlow) ...[
                        StepProgress(
                          labels: const ['Documents', 'Facial Scan'],
                          states: [
                            _hasIdDoc ? StepDotState.done : StepDotState.current,
                            _hasSelfie ? StepDotState.done : StepDotState.pending,
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── Step 1: Documents ──────────────────────────────────
                      if (_showUploadFlow) ...[
                        _StepHeader(number: 1, title: 'Upload Identity Document',
                            done: _hasIdDoc),
                        const SizedBox(height: 12),
                        if (_docs.isNotEmpty) ...[
                          ..._docs.map((d) => _DocCard(
                            doc: d, dateFmt: _dateFmt,
                            onDelete: d.isVerified ? null : () => _deleteDoc(d),
                          )),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _showUploadSheet,
                            icon: const Icon(UniconsLine.plus, size: 16, color: AppColors.emeraldDeep),
                            label: const Text('Add Another Document',
                                style: TextStyle(color: AppColors.emeraldDeep, fontSize: 13)),
                          ),
                        ] else
                          SizedBox(
                            width: double.infinity, height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _showUploadSheet,
                              icon: const Icon(UniconsLine.export),
                              label: Text('Upload Document', style: GoogleFonts.sora(fontWeight: FontWeight.w800)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.emeraldDeep,
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],

                      // ── Step 2: Facial Scan ────────────────────────────────
                      if (_showUploadFlow) ...[
                        _StepHeader(number: 2, title: 'Facial Scan (Liveness Check)',
                            done: _hasSelfie, locked: !_hasIdDoc),
                        const SizedBox(height: 12),
                        _SelfieCard(
                          hasSelfie: _hasSelfie,
                          selfieStatus: _selfieStatus,
                          locked: !_hasIdDoc,
                          onTap: _hasIdDoc ? _goToSelfie : null,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── Verified docs list ─────────────────────────────────
                      if (_kycStatus == 'Verified' && _docs.isNotEmpty) ...[
                        Text('Verified Documents',
                            style: TextStyle(color: c.textPrimary,
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        ..._docs.map((d) => _DocCard(doc: d, dateFmt: _dateFmt)),
                      ],
                          ],
                        ),
                      ),
          ),
        ]),
      ),
    );
  }
}

// ── Step Header ───────────────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  final int number; final String title; final bool done; final bool locked;
  const _StepHeader({required this.number, required this.title,
    required this.done, this.locked = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = done ? AppColors.emeraldMid : locked ? c.textHint : AppColors.emeraldDeep;
    return Row(children: [
      Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
        child: Center(
          child: done
              ? Icon(UniconsLine.check, color: Colors.white, size: 14)
              : Text('$number',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(title,
            style: TextStyle(
                color: locked ? c.textHint : c.textPrimary,
                fontSize: 15, fontWeight: FontWeight.w700)),
      ),
      if (done)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
              color: AppColors.emeraldMid,
              borderRadius: BorderRadius.circular(6)),
          child: const Text('Done',
              style: TextStyle(color: Colors.white, fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ),
    ]);
  }
}

// ── Selfie Card ───────────────────────────────────────────────────────────────

class _SelfieCard extends StatelessWidget {
  final bool hasSelfie, locked;
  final String? selfieStatus;
  final VoidCallback? onTap;
  const _SelfieCard({required this.hasSelfie, required this.locked,
    this.selfieStatus, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (locked) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border, width: .5),
        ),
        child: Row(children: [
          Icon(UniconsLine.lock, color: c.textHint, size: 20),
          const SizedBox(width: 12),
          Text('Complete Step 1 first',
              style: TextStyle(color: c.textHint, fontSize: 13)),
        ]),
      );
    }

    final statusColor = selfieStatus == 'Verified'
        ? AppColors.emeraldMid
        : selfieStatus == 'Rejected'
            ? AppColors.danger
            : AppColors.gold;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasSelfie
                ? statusColor.withValues(alpha: .4)
                : AppColors.emeraldDeep.withValues(alpha: .3),
            width: .8,
          ),
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasSelfie ? statusColor : AppColors.emeraldDeep,
            ),
            child: Icon(
              hasSelfie ? UniconsLine.check_circle : UniconsLine.smile,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(hasSelfie ? 'Facial Scan Submitted' : 'Start Facial Scan',
                style: TextStyle(
                    color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(
              hasSelfie
                  ? (selfieStatus == 'Verified'
                      ? 'Facial scan approved ✓'
                      : selfieStatus == 'Rejected'
                          ? 'Rejected — tap to redo the scan'
                          : 'Under review by our team')
                  : 'Live camera scan with blink verification',
              style: TextStyle(color: c.textSecondary, fontSize: 12),
            ),
          ])),
          Icon(
            hasSelfie && selfieStatus != 'Rejected'
                ? UniconsLine.check_circle
                : UniconsLine.angle_right,
            color: hasSelfie && selfieStatus == 'Verified'
                ? AppColors.emeraldMid : c.textHint,
            size: 20,
          ),
        ]),
      ),
    );
  }
}

// ── Status Banner ─────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final String status; final String? verifiedAt; final DateFormat dateFmt;
  final bool locked; final String? demotionReason; final String? reviewDueAt;
  const _StatusBanner({required this.status, this.verifiedAt, required this.dateFmt,
    this.locked = false, this.demotionReason, this.reviewDueAt});

  // Human-readable reason a member dropped out of Verified.
  String? get _reasonText {
    switch (demotionReason) {
      case 'periodic_review':  return 'A periodic identity review is due — please re-confirm your documents.';
      case 'expired_document': return 'An identity document has expired — please upload a current one.';
      case 'document_rejected':return 'A document was rejected — please review the notes and resubmit.';
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    IconData icon;
    String title, sub;

    // Locked overrides every other state — the member can't resubmit until unlocked.
    if (locked) {
      bg = AppColors.danger; fg = Colors.white;
      icon = UniconsLine.lock;
      title = 'KYC Locked';
      sub = 'Your verification is locked after repeated rejections. Please contact the SACCO to continue.';
      return _box(context, bg, fg, icon, title, sub);
    }

    switch (status) {
      case 'Verified':
        bg = AppColors.emeraldMid; fg = Colors.white;
        icon = UniconsLine.check_circle;
        title = 'KYC Verified';
        sub = verifiedAt != null
            ? 'Verified on ${dateFmt.format(DateTime.parse(verifiedAt!))}'
            : 'Your identity has been verified.';
        if (reviewDueAt != null) {
          sub += '\nNext review due ${dateFmt.format(DateTime.parse(reviewDueAt!))}.';
        }
        break;
      case 'Rejected':
        bg = AppColors.danger; fg = Colors.white;
        icon = UniconsLine.exclamation_triangle;
        title = 'KYC Rejected';
        sub = _reasonText ?? 'Your submission was rejected. Please review the notes below and resubmit.';
        break;
      case 'Pending':
        bg = AppColors.gold; fg = Colors.black;
        icon = UniconsLine.clock;
        title = _reasonText != null ? 'Re-verification Needed' : 'Under Review';
        sub = _reasonText ?? 'Your documents and facial scan are being reviewed (1–2 business days).';
        break;
      default:
        bg = context.colors.surface; fg = context.colors.textPrimary;
        icon = Icons.verified_user_outlined;
        title = 'Identity Not Verified';
        sub = 'Complete both steps below to get KYC verified.';
    }
    return _box(context, bg, fg, icon, title, sub);
  }

  Widget _box(BuildContext context, Color bg, Color fg, IconData icon, String title, String sub) {

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(icon, color: fg, size: 36),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(sub,
              style: TextStyle(color: fg.withValues(alpha: .85), fontSize: 12)),
        ])),
      ]),
    );
  }
}

// ── Document Card ─────────────────────────────────────────────────────────────

class _DocCard extends StatelessWidget {
  final KycDocument doc; final DateFormat dateFmt; final VoidCallback? onDelete;
  const _DocCard({required this.doc, required this.dateFmt, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final statusColor = doc.isVerified
        ? AppColors.emeraldMid : doc.isRejected ? AppColors.danger : AppColors.gold;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: .5),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(12)),
          child: Icon(_docIcon(doc.documentType), color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(doc.documentType,
                style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            if (doc.side != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(4)),
                child: Text(doc.side!.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
          const SizedBox(height: 3),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(6)),
              child: Text(doc.status,
                  style: const TextStyle(color: Colors.white, fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
            if (doc.documentNumber != null) ...[
              const SizedBox(width: 8),
              Text(doc.documentNumber!,
                  style: TextStyle(color: c.textSecondary, fontSize: 11)),
            ],
          ]),
          if (doc.isRejected && doc.notes != null) ...[
            const SizedBox(height: 4),
            Text('Reason: ${doc.notes}',
                style: const TextStyle(color: AppColors.danger, fontSize: 11)),
          ],
        ])),
        if (onDelete != null)
          IconButton(
            icon: Icon(UniconsLine.trash_alt, color: c.textHint, size: 20),
            onPressed: onDelete,
          ),
      ]),
    );
  }

  IconData _docIcon(String type) {
    switch (type) {
      case 'National ID':      return UniconsLine.user_square;
      case 'Driving License':  return UniconsLine.car;
      case 'Staff ID Card':    return UniconsLine.postcard;
      default:                 return UniconsLine.file_alt;
    }
  }
}

// ── Upload Sheet ──────────────────────────────────────────────────────────────

class _UploadSheet extends StatefulWidget {
  final VoidCallback onUploaded;
  const _UploadSheet({required this.onUploaded});
  @override State<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends State<_UploadSheet> {
  final _api      = ApiService();
  final _numCtrl  = TextEditingController();
  final _cardCtrl = TextEditingController();
  String    _docType    = _docTypes.first;
  File?     _frontFile;
  File?     _backFile;
  bool      _busy       = false;
  DateTime? _expiryDate;

  bool get _needsBothSides => _twoSided.contains(_docType);
  bool get _canSubmit =>
      _frontFile != null && (!_needsBothSides || _backFile != null);

  @override
  void dispose() { _numCtrl.dispose(); _cardCtrl.dispose(); super.dispose(); }

  Future<void> _pickExpiryDate() async {
    final now    = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now.add(const Duration(days: 365)),
      firstDate: DateTime(1950),
      lastDate: DateTime(2060),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.emeraldDeep),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _capture({required bool isFront}) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 88,
      maxWidth: 1400,
    );
    if (picked != null) {
      setState(() {
        if (isFront) _frontFile = File(picked.path);
        else         _backFile  = File(picked.path);
      });
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _busy = true);
    try {
      final docNum  = _numCtrl.text.trim().isEmpty ? null : _numCtrl.text.trim();
      final card    = _cardCtrl.text.trim().isEmpty ? null : _cardCtrl.text.trim();
      final expiry  = _expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : null;

      if (_needsBothSides) {
        // Upload front then back as separate documents
        await _api.uploadKycDocument(
          file: _frontFile!, documentType: _docType, side: 'front',
          documentNumber: docNum, cardNumber: card, expiryDate: expiry,
        );
        await _api.uploadKycDocument(
          file: _backFile!, documentType: _docType, side: 'back',
        );
      } else {
        await _api.uploadKycDocument(
          file: _frontFile!, documentType: _docType, side: 'front',
          documentNumber: docNum, cardNumber: card, expiryDate: expiry,
        );
      }
      widget.onUploaded();
    } catch (e) {
      _snack(ApiService.extractError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('Upload Document',
              style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Photos must be taken with your camera — no gallery uploads.',
              style: TextStyle(color: c.textHint, fontSize: 12)),
          const SizedBox(height: 20),

          // Document type
          Text('Document Type',
              style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: c.surface,
                borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _docType, isExpanded: true, dropdownColor: c.card,
                style: TextStyle(color: c.textPrimary, fontSize: 14),
                items: _docTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) {
                  if (v != null) setState(() {
                    _docType = v;
                    _frontFile = null;
                    _backFile  = null;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Document number
          Text('Document Number (optional)',
              style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _numCtrl, style: TextStyle(color: c.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. CM12345678', hintStyle: TextStyle(color: c.textHint),
              filled: true, fillColor: c.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.border)),
              focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: AppColors.emeraldDeep, width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),

          // Card Number (Ugandan National IDs carry a 9-digit card number, not an issue date)
          Text('Card Number',
              style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _cardCtrl, style: TextStyle(color: c.textPrimary),
            keyboardType: TextInputType.number,
            maxLength: 9,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              hintText: '9-digit card number', hintStyle: TextStyle(color: c.textHint),
              filled: true, fillColor: c.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.border)),
              focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: AppColors.emeraldDeep, width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),

          // Expiry date
          _DateField(
            label: 'Expiry Date', value: _expiryDate, hint: 'Select date',
            onTap: _pickExpiryDate,
          ),
          const SizedBox(height: 20),

          // Camera capture areas
          if (_needsBothSides) ...[
            Text('Document Photos — Front & Back Required',
                style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _CaptureSlot(
                label: 'FRONT',
                file: _frontFile,
                onCapture: () => _capture(isFront: true),
                onClear: () => setState(() => _frontFile = null),
              )),
              const SizedBox(width: 10),
              Expanded(child: _CaptureSlot(
                label: 'BACK',
                file: _backFile,
                onCapture: () => _capture(isFront: false),
                onClear: () => setState(() => _backFile = null),
              )),
            ]),
          ] else ...[
            Text('Document Photo',
                style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: _CaptureSlot(
                label: 'PHOTO',
                file: _frontFile,
                onCapture: () => _capture(isFront: true),
                onClear: () => setState(() => _frontFile = null),
              ),
            ),
          ],

          if (_needsBothSides) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(_frontFile != null ? UniconsLine.check_circle : UniconsLine.circle,
                  size: 14,
                  color: _frontFile != null ? AppColors.emeraldMid : c.textHint),
              const SizedBox(width: 4),
              Text('Front captured',
                  style: TextStyle(
                      fontSize: 11,
                      color: _frontFile != null ? AppColors.emeraldMid : c.textHint)),
              const SizedBox(width: 16),
              Icon(_backFile != null ? UniconsLine.check_circle : UniconsLine.circle,
                  size: 14,
                  color: _backFile != null ? AppColors.emeraldMid : c.textHint),
              const SizedBox(width: 4),
              Text('Back captured',
                  style: TextStyle(
                      fontSize: 11,
                      color: _backFile != null ? AppColors.emeraldMid : c.textHint)),
            ]),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: (_busy || !_canSubmit) ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldDeep, foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: _busy
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text(
                      _needsBothSides && _backFile == null && _frontFile != null
                          ? 'Capture Back Side to Continue'
                          : 'Submit Document',
                      style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Camera Capture Slot ───────────────────────────────────────────────────────

class _CaptureSlot extends StatelessWidget {
  final String label;
  final File?  file;
  final VoidCallback onCapture;
  final VoidCallback onClear;
  const _CaptureSlot({required this.label, required this.file,
      required this.onCapture, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (file != null) {
      return Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(file!, height: 130, width: double.infinity,
              fit: BoxFit.cover),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppColors.emeraldMid)),
          const SizedBox(width: 4),
          const Icon(UniconsLine.check_circle, color: AppColors.emeraldMid, size: 12),
          const Spacer(),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retake',
                style: TextStyle(color: AppColors.danger, fontSize: 11)),
          ),
        ]),
      ]);
    }

    return GestureDetector(
      onTap: onCapture,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.emeraldDeep.withValues(alpha: .4),
              style: BorderStyle.solid, width: 1.5),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.emeraldDeep,
              shape: BoxShape.circle,
            ),
            child: const Icon(UniconsLine.camera, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(color: AppColors.emeraldDeep, fontSize: 11,
                  fontWeight: FontWeight.w700, letterSpacing: .5)),
          const SizedBox(height: 2),
          Text('Tap to capture', style: TextStyle(color: c.textHint, fontSize: 10)),
        ]),
      ),
    );
  }
}

// ── Date Field ────────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  final String label; final DateTime? value; final String hint;
  final VoidCallback onTap;
  const _DateField({required this.label, required this.value,
    required this.hint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12,
          fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: c.surface, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Row(children: [
            Expanded(child: Text(
              value != null ? DateFormat('dd MMM yyyy').format(value!) : hint,
              style: TextStyle(
                color: value != null ? c.textPrimary : c.textHint,
                fontSize: 14,
              ),
            )),
            Icon(UniconsLine.calendar_alt, color: AppColors.emeraldDeep, size: 16),
          ]),
        ),
      ),
    ]);
  }
}

// ── Error View ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message; final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(UniconsLine.info_circle, size: 48, color: AppColors.danger),
      const SizedBox(height: 12),
      Text('Failed to load KYC status',
          style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      TextButton(onPressed: onRetry,
          child: const Text('Retry', style: TextStyle(color: AppColors.emeraldDeep))),
    ]),
  );
}
