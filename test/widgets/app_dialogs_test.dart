// Widget tests for lib/widgets/app_dialogs.dart — the AppDialogs modal
// helpers used for failures serious enough that a snackbar isn't enough.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bmcsacco_app/theme/app_theme.dart';
import 'package:bmcsacco_app/widgets/app_dialogs.dart';

/// A minimal host screen whose button hands its onPressed callback the
/// BuildContext, since every AppDialogs call needs one (Navigator/
/// ScaffoldMessenger above it to show the dialog/snackbar from).
Widget _hostAppWithContext(void Function(BuildContext) onPressed,
        {NavigatorObserver? observer}) =>
    MaterialApp(
      theme: AppTheme.light,
      navigatorObservers: observer != null ? [observer] : const [],
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => onPressed(context),
            child: const Text('trigger'),
          ),
        ),
      ),
    );

void main() {
  group('AppDialogs.showError', () {
    testWidgets('shows OK button (no retry) when onRetry is omitted', (tester) async {
      await tester.pumpWidget(_hostAppWithContext((context) {
        AppDialogs.showError(context, message: 'Failed to load your loans.');
      }));

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Failed to load your loans.'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'OK'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsNothing);
    });

    testWidgets('shows Retry button and invokes onRetry, dismissing the dialog',
        (tester) async {
      var retried = false;
      await tester.pumpWidget(_hostAppWithContext((context) {
        AppDialogs.showError(
          context,
          title: 'Load failed',
          message: 'Please try again.',
          onRetry: () => retried = true,
        );
      }));

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      expect(find.text('Load failed'), findsOneWidget);
      final retryButton = find.widgetWithText(ElevatedButton, 'Retry');
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      await tester.pumpAndSettle();

      expect(retried, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('AppDialogs.showPaymentFailed', () {
    testWidgets('shows title, message and reference when provided', (tester) async {
      await tester.pumpWidget(_hostAppWithContext((context) {
        AppDialogs.showPaymentFailed(
          context,
          message: 'Insufficient funds.',
          reference: 'TXN-12345',
          onRetry: () {},
        );
      }));

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      expect(find.text('Payment Failed'), findsOneWidget);
      expect(find.textContaining('Insufficient funds.'), findsOneWidget);
      expect(find.textContaining('Reference: TXN-12345'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Try Again'), findsOneWidget);
    });

    testWidgets('shows OK (no retry) and no reference line when both omitted',
        (tester) async {
      await tester.pumpWidget(_hostAppWithContext((context) {
        AppDialogs.showPaymentFailed(context, message: 'Card declined.');
      }));

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      expect(find.text('Card declined.'), findsOneWidget);
      expect(find.textContaining('Reference:'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'OK'), findsOneWidget);
    });
  });

  group('AppDialogs.showAccessDenied', () {
    testWidgets('with no onRequestAccess shows only an OK button', (tester) async {
      await tester.pumpWidget(_hostAppWithContext((context) {
        AppDialogs.showAccessDenied(context);
      }));

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      expect(find.text('Access Denied'), findsOneWidget);
      expect(find.text('You don\'t have permission to do that.'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'OK'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Dismiss'), findsNothing);
    });

    testWidgets('with onRequestAccess shows Request Access + Dismiss, and Request Access invokes callback',
        (tester) async {
      var requested = false;
      await tester.pumpWidget(_hostAppWithContext((context) {
        AppDialogs.showAccessDenied(
          context,
          message: 'Custom access message.',
          onRequestAccess: () => requested = true,
        );
      }));

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      expect(find.text('Custom access message.'), findsOneWidget);
      final requestButton = find.widgetWithText(ElevatedButton, 'Request Access');
      final dismissButton = find.widgetWithText(TextButton, 'Dismiss');
      expect(requestButton, findsOneWidget);
      expect(dismissButton, findsOneWidget);

      await tester.tap(requestButton);
      await tester.pumpAndSettle();

      expect(requested, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Dismiss closes the dialog without invoking onRequestAccess',
        (tester) async {
      var requested = false;
      await tester.pumpWidget(_hostAppWithContext((context) {
        AppDialogs.showAccessDenied(context, onRequestAccess: () => requested = true);
      }));

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Dismiss'));
      await tester.pumpAndSettle();

      expect(requested, isFalse);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('AppDialogs.showSessionExpired', () {
    testWidgets('shows Session Expired copy, a Log In button, and is not barrier-dismissible',
        (tester) async {
      var dismissed = false;
      await tester.pumpWidget(_hostAppWithContext((context) {
        AppDialogs.showSessionExpired(context, onDismiss: () => dismissed = true);
      }));

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      expect(find.text('Session Expired'), findsOneWidget);
      expect(
        find.text('For your security, you\'ve been signed out. Please log in again.'),
        findsOneWidget,
      );

      // Tapping the barrier must NOT dismiss the dialog (barrierDismissible: false).
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(dismissed, isFalse);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('AppDialogs.handleActionError', () {
    testWidgets('403 DioException shows the full Access Denied modal', (tester) async {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/loans/1/approve'),
        response: Response(
          requestOptions: RequestOptions(path: '/loans/1/approve'),
          statusCode: 403,
        ),
        type: DioExceptionType.badResponse,
      );

      await tester.pumpWidget(_hostAppWithContext((context) {
        AppDialogs.handleActionError(context, dioError);
      }));

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Access Denied'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('403 DioException uses accessDeniedMessage override when given',
        (tester) async {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/loans/1/approve'),
        response: Response(
          requestOptions: RequestOptions(path: '/loans/1/approve'),
          statusCode: 403,
        ),
        type: DioExceptionType.badResponse,
      );

      await tester.pumpWidget(_hostAppWithContext((context) {
        AppDialogs.handleActionError(
          context,
          dioError,
          accessDeniedMessage: 'Only board members can approve loans.',
        );
      }));

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      expect(find.text('Only board members can approve loans.'), findsOneWidget);
    });

    testWidgets('a non-403 DioException falls back to a snackbar, not a dialog',
        (tester) async {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/loans/1/approve'),
        response: Response(
          requestOptions: RequestOptions(path: '/loans/1/approve'),
          statusCode: 500,
        ),
        type: DioExceptionType.badResponse,
      );

      await tester.pumpWidget(_hostAppWithContext((context) {
        AppDialogs.handleActionError(context, dioError);
      }));

      await tester.tap(find.text('trigger'));
      await tester.pump(); // SnackBar animates in; no dialog route to settle.

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text('The server is temporarily unavailable. Please try again shortly.'),
        findsOneWidget,
      );
    });

    testWidgets('a generic (non-Dio) error falls back to a snackbar with its message',
        (tester) async {
      await tester.pumpWidget(_hostAppWithContext((context) {
        AppDialogs.handleActionError(context, Exception('Something odd happened'));
      }));

      await tester.tap(find.text('trigger'));
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Something odd happened'), findsOneWidget);
    });
  });
}
