import 'package:flutter/material.dart';
import '../models/member.dart';
import '../screens/kyc/kyc_screen.dart';
import '../theme/app_theme.dart';
import 'package:unicons/unicons.dart';

// Returns true if access granted; false + shows a bottom sheet if not.
class FeatureGate {
  static bool requireKyc(
    BuildContext context, {
    required Member? member,
    required String feature,
    required VoidCallback onGranted,
  }) {
    if (member != null && member.isKycVerified) {
      onGranted();
      return true;
    }
    _show(context, member: member, needsKyc: true, needsFee: false, feature: feature);
    return false;
  }

  static bool requireFull(
    BuildContext context, {
    required Member? member,
    required String feature,
    required VoidCallback onGranted,
  }) {
    final kycOk = member?.isKycVerified == true;
    final feeOk = member?.subscriptionFeePaid == true;
    if (kycOk && feeOk) {
      onGranted();
      return true;
    }
    _show(context, member: member, needsKyc: !kycOk, needsFee: !feeOk, feature: feature);
    return false;
  }

  static void _show(
    BuildContext context, {
    required Member? member,
    required bool needsKyc,
    required bool needsFee,
    required String feature,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _GateSheet(
        feature: feature,
        needsKyc: needsKyc,
        needsFee: needsFee,
        kycStatus: member?.kycStatus ?? 'Unverified',
      ),
    );
  }
}

class _GateSheet extends StatelessWidget {
  final String feature;
  final bool   needsKyc;
  final bool   needsFee;
  final String kycStatus;

  const _GateSheet({
    required this.feature,
    required this.needsKyc,
    required this.needsFee,
    required this.kycStatus,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),

        // Lock icon
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: .1),
            shape: BoxShape.circle,
          ),
          child: const Icon(UniconsLine.lock, color: AppColors.error, size: 30),
        ),
        const SizedBox(height: 16),

        Text('Access Restricted',
            style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('To use $feature, you must complete the following:',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 13)),
        const SizedBox(height: 20),

        // Requirements list
        if (needsKyc)
          _Requirement(
            icon: UniconsLine.shield_check,
            color: AppColors.primary,
            title: 'KYC Verification',
            subtitle: kycStatus == 'Pending'
                ? 'Your documents are under review (1–2 business days)'
                : 'Upload your identity document and complete the facial scan',
          ),
        if (needsKyc && needsFee) const SizedBox(height: 10),
        if (needsFee)
          _Requirement(
            icon: UniconsLine.receipt,
            color: AppColors.warning,
            title: 'Subscription Fee',
            subtitle: 'Pay the one-time membership fee at your nearest branch',
          ),

        const SizedBox(height: 24),

        // Action buttons
        if (needsKyc && kycStatus != 'Pending')
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const KycScreen()));
              },
              icon: const Icon(UniconsLine.shield),
              label: const Text('Complete KYC Now',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity, height: 50,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: c.border),
              foregroundColor: c.textSecondary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Close'),
          ),
        ),
      ]),
    );
  }
}

class _Requirement extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   title;
  final String   subtitle;
  const _Requirement({required this.icon, required this.color,
      required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(color: c.textPrimary,
                  fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(subtitle,
              style: TextStyle(color: c.textSecondary, fontSize: 12)),
        ])),
      ]),
    );
  }
}
