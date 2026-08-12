import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unicons/unicons.dart';
import '../screens/support/new_support_ticket_screen.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Modal prompts for failures serious enough that the user must actively
/// acknowledge (or act on) them, rather than a snackbar/inline text they can
/// miss — payment failures, access-denied, and session expiry.
class AppDialogs {
  AppDialogs._();

  static Future<void> _show(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    required String primaryLabel,
    VoidCallback? onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
    bool barrierDismissible = true,
  }) {
    final c = context.colors;
    return showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(title,
              style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 16, color: c.textPrimary))),
        ]),
        content: Text(message, style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4)),
        actions: [
          if (secondaryLabel != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onSecondary?.call();
              },
              child: Text(secondaryLabel, style: TextStyle(color: c.textSecondary)),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onPrimary?.call();
            },
            style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
            child: Text(primaryLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// Generic action-required error — use when a failure needs explicit
  /// dismissal/acknowledgement instead of a passing snackbar.
  static Future<void> showError(
    BuildContext context, {
    String title = 'Something went wrong',
    required String message,
    VoidCallback? onRetry,
  }) =>
      _show(
        context,
        icon: UniconsLine.exclamation_triangle,
        color: AppColors.danger,
        title: title,
        message: message,
        primaryLabel: onRetry != null ? 'Retry' : 'OK',
        onPrimary: onRetry,
      );

  /// A payment attempt failed — always requires the member to consciously
  /// see the failure (and reference/reason if available) before retrying,
  /// rather than risk them missing an inline banner and assuming it went through.
  static Future<void> showPaymentFailed(
    BuildContext context, {
    required String message,
    String? reference,
    VoidCallback? onRetry,
  }) =>
      _show(
        context,
        icon: UniconsLine.times_circle,
        color: AppColors.danger,
        title: 'Payment Failed',
        message: reference != null ? '$message\n\nReference: $reference' : message,
        primaryLabel: onRetry != null ? 'Try Again' : 'OK',
        onPrimary: onRetry,
      );

  /// 403 from the API — explains the member can't perform this action and
  /// offers a one-tap way to ask for access instead of a dead end.
  static Future<void> showAccessDenied(
    BuildContext context, {
    String message = 'You don\'t have permission to do that.',
    VoidCallback? onRequestAccess,
  }) =>
      _show(
        context,
        icon: UniconsLine.lock_access,
        color: AppColors.danger,
        title: 'Access Denied',
        message: message,
        primaryLabel: onRequestAccess != null ? 'Request Access' : 'OK',
        onPrimary: onRequestAccess,
        secondaryLabel: onRequestAccess != null ? 'Dismiss' : null,
      );

  /// Drop-in replacement for the common "catch (e) { showSnackBar(extractError(e)) }"
  /// pattern on mutation actions (delete/revoke/vote/pay/etc). A 403 gets the
  /// full Access Denied modal with a Request Access path instead of a snackbar
  /// that's easy to miss and offers no way forward; everything else falls back
  /// to the existing snackbar behaviour unchanged.
  static void handleActionError(BuildContext context, Object error, {String? accessDeniedMessage}) {
    if (error is DioException && error.response?.statusCode == 403) {
      showAccessDenied(
        context,
        message: accessDeniedMessage ?? 'You don\'t have permission to do that.',
        onRequestAccess: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => const NewSupportTicketScreen(
            initialCategory: 'account_access',
            initialSubject: 'Requesting access',
          ),
        )),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ApiService.extractError(error)),
      backgroundColor: AppColors.danger,
    ));
  }

  /// Session expired (401). Shown before the router redirect to /login so the
  /// member understands why they were signed out, instead of just landing
  /// back on the login screen with no explanation.
  static Future<void> showSessionExpired(BuildContext context, {VoidCallback? onDismiss}) =>
      _show(
        context,
        icon: UniconsLine.clock,
        color: AppColors.gold,
        title: 'Session Expired',
        message: 'For your security, you\'ve been signed out. Please log in again.',
        primaryLabel: 'Log In',
        onPrimary: onDismiss,
        barrierDismissible: false,
      );
}
