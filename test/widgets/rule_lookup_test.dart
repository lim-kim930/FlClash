import 'dart:async';

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/core/rule_lookup.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/rule_lookup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_app.dart';

class _LookupHandler extends Mock implements CoreHandlerInterface {}

const _result = RuleLookupResult(
  target: 'example.com',
  port: 443,
  network: 'tcp',
  mode: 'rule',
  rule: 'Domain',
  rulePayload: 'example.com',
  proxy: 'Proxy',
  chains: ['Proxy', 'node-a'],
  destinationIp: '',
);

void main() {
  late _LookupHandler handler;

  setUp(() {
    handler = _LookupHandler();
    when(
      () => handler.ruleLookup(
        target: any(named: 'target'),
        port: any(named: 'port'),
        network: any(named: 'network'),
      ),
    ).thenAnswer((_) async => _result);
  });

  Future<ProviderContainer> mount(
    WidgetTester tester, {
    bool connected = true,
  }) async {
    final container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(handler)),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(coreStatusProvider.notifier).value = connected
        ? CoreStatus.connected
        : CoreStatus.disconnected;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(
          includeNavigatorKey: false,
          locale: Locale('en'),
          child: RuleLookupView(),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  Future<void> query(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Check route');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  testWidgets('shows the matched policy and clears results after edits', (
    tester,
  ) async {
    await mount(tester);
    await tester.enterText(find.byType(TextFormField).first, 'example.com');
    await query(tester);
    expect(find.text('Domain'), findsOneWidget);
    expect(find.text('Proxy → node-a'), findsOneWidget);
    verify(
      () =>
          handler.ruleLookup(target: 'example.com', port: 443, network: 'tcp'),
    ).called(1);
    await tester.enterText(find.byType(TextFormField).first, 'example.org');
    await tester.pump();
    expect(find.text('Proxy → node-a'), findsNothing);
  });

  testWidgets('rejects URLs and ports outside the destination range', (
    tester,
  ) async {
    await mount(tester);
    await tester.enterText(
      find.byType(TextFormField).first,
      'https://example.com',
    );
    await query(tester);
    expect(
      find.text('Enter a valid domain or IP address without a URL or port'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextFormField).first, '2001:db8::1');
    await tester.enterText(find.byType(TextFormField).last, '65536');
    await query(tester);
    expect(find.text('Enter a port between 1 and 65535'), findsOneWidget);
    verifyNever(
      () => handler.ruleLookup(
        target: any(named: 'target'),
        port: any(named: 'port'),
        network: any(named: 'network'),
      ),
    );
  });

  testWidgets('disables queries until the core is connected', (tester) async {
    final container = await mount(tester, connected: false);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      find.text('Connect the core before checking a route'),
      findsOneWidget,
    );
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('releases loading state after failure and permits retry', (
    tester,
  ) async {
    final pending = Completer<RuleLookupResult>();
    when(
      () =>
          handler.ruleLookup(target: 'example.com', port: 443, network: 'tcp'),
    ).thenAnswer((_) => pending.future);
    await mount(tester);
    await tester.enterText(find.byType(TextFormField).first, 'example.com');
    await query(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.completeError(
      const CoreMethodException(code: 'no_response', message: 'unavailable'),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.text(
        "Couldn't check the route. Check the core and DNS, then try again",
      ),
      findsOneWidget,
    );
    when(
      () =>
          handler.ruleLookup(target: 'example.com', port: 443, network: 'tcp'),
    ).thenAnswer((_) async => _result);
    await query(tester);
    expect(find.text('Proxy → node-a'), findsOneWidget);
  });

  testWidgets('ignores completion after the page is disposed', (tester) async {
    final pending = Completer<RuleLookupResult>();
    when(
      () =>
          handler.ruleLookup(target: 'example.com', port: 443, network: 'tcp'),
    ).thenAnswer((_) => pending.future);
    await mount(tester);
    await tester.enterText(find.byType(TextFormField).first, 'example.com');
    await query(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(_result);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
