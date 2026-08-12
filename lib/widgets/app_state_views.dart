import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unicons/unicons.dart';
import '../theme/app_theme.dart';
import 'app_animations.dart';

/// Shared centered layout used by every state view below: icon tile, title,
/// optional subtitle, optional primary action.
class _StateScaffold extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? customIcon;
  const _StateScaffold({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.customIcon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          customIcon ??
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppColors.solidTint(iconColor, Theme.of(context).brightness == Brightness.dark),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
          const SizedBox(height: 18),
          Text(title,
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(
                  fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary)),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4)),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emeraldDeep,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                ),
                child: Text(actionLabel!,
                    style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Nothing to show yet (empty list, no records). Distinct from [ErrorStateView]
/// — this is a normal, expected condition, not a failure.
class EmptyStateView extends StatelessWidget {
  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyStateView({
    super.key,
    this.title = 'Nothing here yet',
    this.message,
    this.icon = UniconsLine.inbox,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => _StateScaffold(
        icon: icon,
        iconColor: AppColors.gold,
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
      );
}

/// A search/filter returned nothing — separate from [EmptyStateView] so the
/// copy can point at "try a different search" instead of "nothing here yet".
class NoSearchResultsStateView extends StatelessWidget {
  final String query;
  final VoidCallback? onClear;
  const NoSearchResultsStateView({super.key, required this.query, this.onClear});

  @override
  Widget build(BuildContext context) => _StateScaffold(
        icon: UniconsLine.search,
        iconColor: AppColors.gold,
        title: 'No results for "$query"',
        message: 'Try a different keyword or check the spelling.',
        actionLabel: onClear != null ? 'Clear search' : null,
        onAction: onClear,
      );
}

/// Centered spinner for a full-screen/section loading state, with an optional
/// label for longer operations.
class LoadingStateView extends StatelessWidget {
  final String? message;
  const LoadingStateView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(color: AppColors.emeraldDeep),
        if (message != null) ...[
          const SizedBox(height: 14),
          Text(message!, style: TextStyle(color: c.textSecondary, fontSize: 13)),
        ],
      ]),
    );
  }
}

/// A request that started more than a few seconds ago and hasn't returned —
/// shown alongside (not instead of) the spinner so a slow connection doesn't
/// look identical to a hang. Wrap a normal loading view with
/// [SlowNetworkNotice.after] to show it automatically.
class SlowNetworkNotice extends StatelessWidget {
  const SlowNetworkNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.solidTint(AppColors.gold, Theme.of(context).brightness == Brightness.dark),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(UniconsLine.clock, color: AppColors.gold, size: 14),
        const SizedBox(width: 6),
        Text('This is taking longer than usual…',
            style: TextStyle(color: c.textSecondary, fontSize: 11)),
      ]),
    );
  }

  /// Shows itself only once [delay] has elapsed while still mounted under a
  /// loading state — avoids flashing "slow network" on every ordinary request.
  static Widget after({Duration delay = const Duration(seconds: 6)}) =>
      _DelayedVisibility(delay: delay, child: const SlowNetworkNotice());
}

class _DelayedVisibility extends StatefulWidget {
  final Duration delay;
  final Widget child;
  const _DelayedVisibility({required this.delay, required this.child});
  @override
  State<_DelayedVisibility> createState() => _DelayedVisibilityState();
}

class _DelayedVisibilityState extends State<_DelayedVisibility> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedOpacity(opacity: _show ? 1 : 0, duration: const Duration(milliseconds: 300), child: widget.child);
}

/// Generic "couldn't load this" state for a failed fetch, with a retry action.
class ErrorStateView extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  const ErrorStateView({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => _StateScaffold(
        icon: UniconsLine.exclamation_triangle,
        iconColor: AppColors.danger,
        title: 'Something went wrong',
        message: message ?? 'We couldn\'t load this. Please try again.',
        actionLabel: onRetry != null ? 'Retry' : null,
        onAction: onRetry,
      );
}

/// Full-screen "you're offline" state for screens that have no cached data
/// to fall back on (as opposed to the transient top banner in
/// [ConnectivityBanner], which layers over whatever content is already shown).
class NoInternetStateView extends StatelessWidget {
  final VoidCallback? onRetry;
  const NoInternetStateView({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) => _StateScaffold(
        icon: UniconsLine.wifi_slash,
        iconColor: AppColors.danger,
        title: 'No internet connection',
        message: 'Check your connection and try again.',
        actionLabel: onRetry != null ? 'Retry' : null,
        onAction: onRetry,
      );
}

/// 403 / role-gated content the current member can't access.
class PermissionDeniedStateView extends StatelessWidget {
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const PermissionDeniedStateView({
    super.key,
    this.message,
    this.actionLabel = 'Request Access',
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => _StateScaffold(
        icon: UniconsLine.lock_access,
        iconColor: AppColors.danger,
        title: 'Access denied',
        message: message ?? 'You don\'t have permission to view this.',
        actionLabel: onAction != null ? actionLabel : null,
        onAction: onAction,
      );
}

/// Confirmation screen/section after an action completes successfully
/// (payment, application submitted, etc). Reuses the existing [SuccessCheck]
/// draw-on animation rather than a static check icon.
class SuccessStateView extends StatelessWidget {
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SuccessStateView({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => _StateScaffold(
        customIcon: const SuccessCheck(size: 76, color: AppColors.emeraldMid),
        icon: UniconsLine.check_circle,
        iconColor: AppColors.emeraldMid,
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
      );
}
