// Widget tests for lib/widgets/connectivity_banner.dart.
//
// ConnectivityBanner is driven by ConnectivityService.instance, a hard
// singleton (lib/services/connectivity_service.dart) with no dependency
// injection seam: initState() unconditionally calls
// `ConnectivityService.instance.start()`, which wraps the real
// `connectivity_plus` platform channel AND performs a genuine
// `InternetAddress.lookup('one.one.one.one')` DNS probe on every link-up
// event.
//
// That DNS probe cannot be faked from a widget test:
//   - `dart:io`'s `IOOverrides` exposes a `lookup()` hook that looks like it
//     should intercept `InternetAddress.lookup`, but empirically it does not
//     (verified directly: overriding it and calling
//     `InternetAddress.lookup('one.one.one.one')` still returns real
//     Cloudflare addresses over the network, not the fake ones). So there is
//     no supported way to fake DNS resolution for this static API.
//   - `ConnectivityService` is a private singleton (`instance`) with no
//     constructor injection for a fake prober/Connectivity, so we can't swap
//     in a test double either.
//
// Driving the banner through its offline/checking/online states therefore
// isn't practical without either (a) modifying the source to accept an
// injected probe function/Connectivity instance (out of scope for this test
// pass — told not to touch non-test source without a real bug), or (b) an
// end-to-end/integration test that manipulates the real network, which is
// exactly the kind of flaky, environment-dependent test we don't want.
//
// So this file sticks to what's genuinely deterministic: the banner's
// initial render (hidden, per `_visible == null` until any stream event
// arrives) and that mounting/unmounting it doesn't throw. We deliberately
// avoid `pumpAndSettle`/awaiting anything here, since that would block on
// the real network probe kicked off by `start()`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bmcsacco_app/theme/app_theme.dart';
import 'package:bmcsacco_app/widgets/connectivity_banner.dart';

void main() {
  testWidgets('renders hidden (no status text) on first frame before any connectivity event',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      theme: null, // banner text styling doesn't depend on AppColorScheme.
      home: Scaffold(body: ConnectivityBanner()),
    ));
    await tester.pump();

    // Initial state is `_visible = null` => transparent banner with empty
    // label; none of the possible status strings should be showing yet.
    expect(find.text('No internet connection'), findsNothing);
    expect(find.text('Connecting…'), findsNothing);
    expect(find.text('Back online'), findsNothing);

    // ConnectivityService.start() kicked off a real InternetAddress.lookup()
    // wrapped in a 4s .timeout(). Widget tests run inside a fake-time zone,
    // so that timeout is a fake Timer we can (and must) fast-forward past
    // here — otherwise the test binding's teardown assertion
    // ("A Timer is still pending even after the widget tree was disposed")
    // fails. This does not make the DNS outcome itself deterministic (real
    // network I/O still races the fake clock), it just guarantees the timer
    // is drained before the test ends.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('mounts and unmounts cleanly without throwing', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: ConnectivityBanner()),
    ));
    await tester.pump();

    // Swap it out for an empty tree; this exercises dispose() (subscription
    // + timer cancellation) and must not throw or leave a pending timer that
    // fails the test's teardown checks.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('is wrapped so it never intercepts touches (IgnorePointer over content)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: ConnectivityBanner()),
    ));
    await tester.pump();

    // MaterialApp/Scaffold internals also use IgnorePointer elsewhere in the
    // tree, so scope the search to ConnectivityBanner's own subtree.
    expect(
      find.descendant(
        of: find.byType(ConnectivityBanner),
        matching: find.byType(IgnorePointer),
      ),
      findsOneWidget,
    );

    // Drain the fake timeout timer started by ConnectivityService.start()
    // (see the first test above for why this is necessary).
    await tester.pump(const Duration(seconds: 5));
  });
}
