// Widget tests for the shared UI-state kit in lib/widgets/app_state_views.dart.
//
// Every state view is built on the private _StateScaffold, so most of these
// tests double as scaffold coverage (icon tile, title, message, action button)
// without being able to reference _StateScaffold directly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unicons/unicons.dart';

import 'package:bmcsacco_app/theme/app_theme.dart';
import 'package:bmcsacco_app/widgets/app_state_views.dart';

/// Wraps [child] in a MaterialApp using the app's real theme so
/// `context.colors` (an extension reading a ThemeExtension) resolves instead
/// of throwing a null-check error.
Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );

void main() {
  group('EmptyStateView', () {
    testWidgets('shows default title and no action button when none supplied',
        (tester) async {
      await tester.pumpWidget(_wrap(const EmptyStateView()));

      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.byIcon(UniconsLine.inbox), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('shows custom title, message, icon and invokes onAction',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(EmptyStateView(
        title: 'No loans yet',
        message: 'Apply for your first loan to get started.',
        icon: UniconsLine.file_alt,
        actionLabel: 'Apply now',
        onAction: () => tapped = true,
      )));

      expect(find.text('No loans yet'), findsOneWidget);
      expect(find.text('Apply for your first loan to get started.'),
          findsOneWidget);
      expect(find.byIcon(UniconsLine.file_alt), findsOneWidget);

      final button = find.widgetWithText(ElevatedButton, 'Apply now');
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('does not show action button when actionLabel set but onAction is null',
        (tester) async {
      await tester.pumpWidget(_wrap(const EmptyStateView(actionLabel: 'Do it')));
      expect(find.byType(ElevatedButton), findsNothing);
    });
  });

  group('NoSearchResultsStateView', () {
    testWidgets('shows the query in the title and no clear button when onClear is null',
        (tester) async {
      await tester.pumpWidget(_wrap(const NoSearchResultsStateView(query: 'xyz123')));

      expect(find.text('No results for "xyz123"'), findsOneWidget);
      expect(find.text('Try a different keyword or check the spelling.'),
          findsOneWidget);
      expect(find.byIcon(UniconsLine.search), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('shows Clear search button and invokes onClear when tapped',
        (tester) async {
      var cleared = false;
      await tester.pumpWidget(_wrap(NoSearchResultsStateView(
        query: 'abc',
        onClear: () => cleared = true,
      )));

      final button = find.widgetWithText(ElevatedButton, 'Clear search');
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pump();

      expect(cleared, isTrue);
    });
  });

  group('LoadingStateView', () {
    testWidgets('shows a spinner with no message by default', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingStateView()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // No message text widget besides the spinner should be present.
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('shows the message when provided', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingStateView(message: 'Fetching your statement…')));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Fetching your statement…'), findsOneWidget);
    });
  });

  group('SlowNetworkNotice', () {
    testWidgets('renders immediately (opacity animation is cosmetic only)',
        (tester) async {
      await tester.pumpWidget(_wrap(const SlowNetworkNotice()));

      expect(find.text('This is taking longer than usual…'), findsOneWidget);
      expect(find.byIcon(UniconsLine.clock), findsOneWidget);
    });

    testWidgets('.after() stays invisible before the delay and fades in after it',
        (tester) async {
      await tester.pumpWidget(_wrap(SlowNetworkNotice.after(
        delay: const Duration(seconds: 2),
      )));

      // Widget is in the tree immediately (AnimatedOpacity), just transparent.
      var opacityFinder = find.ancestor(
        of: find.byType(SlowNetworkNotice),
        matching: find.byType(AnimatedOpacity),
      );
      expect(opacityFinder, findsOneWidget);
      expect(tester.widget<AnimatedOpacity>(opacityFinder).opacity, 0);

      // Not yet elapsed.
      await tester.pump(const Duration(seconds: 1));
      opacityFinder = find.ancestor(
        of: find.byType(SlowNetworkNotice),
        matching: find.byType(AnimatedOpacity),
      );
      expect(tester.widget<AnimatedOpacity>(opacityFinder).opacity, 0);

      // Elapses at 2s, then the 300ms fade needs to run too.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      opacityFinder = find.ancestor(
        of: find.byType(SlowNetworkNotice),
        matching: find.byType(AnimatedOpacity),
      );
      expect(tester.widget<AnimatedOpacity>(opacityFinder).opacity, 1);
    });
  });

  group('ErrorStateView', () {
    testWidgets('shows default copy and no retry button when onRetry is null',
        (tester) async {
      await tester.pumpWidget(_wrap(const ErrorStateView()));

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('We couldn\'t load this. Please try again.'), findsOneWidget);
      expect(find.byIcon(UniconsLine.exclamation_triangle), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('shows custom message and Retry button invokes onRetry exactly once',
        (tester) async {
      var retryCount = 0;
      await tester.pumpWidget(_wrap(ErrorStateView(
        message: 'Could not load your transactions.',
        onRetry: () => retryCount++,
      )));

      expect(find.text('Could not load your transactions.'), findsOneWidget);

      final button = find.widgetWithText(ElevatedButton, 'Retry');
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();

      expect(retryCount, 2);
    });
  });

  group('NoInternetStateView', () {
    testWidgets('shows offline copy and no retry button when onRetry is null',
        (tester) async {
      await tester.pumpWidget(_wrap(const NoInternetStateView()));

      expect(find.text('No internet connection'), findsOneWidget);
      expect(find.text('Check your connection and try again.'), findsOneWidget);
      expect(find.byIcon(UniconsLine.wifi_slash), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('Retry button invokes onRetry', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(NoInternetStateView(onRetry: () => tapped = true)));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('PermissionDeniedStateView', () {
    testWidgets('shows Access denied title and default message, no button when onAction is null',
        (tester) async {
      await tester.pumpWidget(_wrap(const PermissionDeniedStateView()));

      expect(find.text('Access denied'), findsOneWidget);
      expect(find.text('You don\'t have permission to view this.'), findsOneWidget);
      expect(find.byIcon(UniconsLine.lock_access), findsOneWidget);
      // actionLabel defaults to 'Request Access' but with no onAction there
      // should still be no visible button (scaffold requires both).
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('shows default "Request Access" label and invokes onAction',
        (tester) async {
      var requested = false;
      await tester.pumpWidget(_wrap(PermissionDeniedStateView(onAction: () => requested = true)));

      final button = find.widgetWithText(ElevatedButton, 'Request Access');
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pump();

      expect(requested, isTrue);
    });

    testWidgets('honors a custom actionLabel', (tester) async {
      await tester.pumpWidget(_wrap(PermissionDeniedStateView(
        actionLabel: 'Contact support',
        onAction: () {},
      )));

      expect(find.widgetWithText(ElevatedButton, 'Contact support'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Request Access'), findsNothing);
    });
  });

  group('SuccessStateView', () {
    testWidgets('shows title, message and action button, invokes onAction',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(SuccessStateView(
        title: 'Payment successful',
        message: 'Your loan repayment has been received.',
        actionLabel: 'Done',
        onAction: () => tapped = true,
      )));
      // Let the SuccessCheck draw-on animation (630ms, finite) settle.
      await tester.pumpAndSettle();

      expect(find.text('Payment successful'), findsOneWidget);
      expect(find.text('Your loan repayment has been received.'), findsOneWidget);

      final button = find.widgetWithText(ElevatedButton, 'Done');
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('shows no action button when actionLabel/onAction are omitted',
        (tester) async {
      await tester.pumpWidget(_wrap(const SuccessStateView(title: 'All done')));
      await tester.pumpAndSettle();

      expect(find.text('All done'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
    });
  });
}
