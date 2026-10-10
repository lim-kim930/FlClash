import 'dart:async';

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/core/rule_lookup.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/rule_lookup.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_app.dart';

class _LookupHandler extends Mock implements CoreHandlerInterface {}

const _result = RuleLookupResult(
  target: 'example.com',
  sourcePort: 0,
  destinationPort: 443,
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
        sourcePort: any(named: 'sourcePort'),
        destinationPort: any(named: 'destinationPort'),
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
        viewSizeProvider.overrideWithBuild(
          (_, _) => tester.view.physicalSize / tester.view.devicePixelRatio,
        ),
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
        child: const TestApp(locale: Locale('en'), child: RuleLookupView()),
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

  Future<void> openInput(WidgetTester tester, String title) async {
    final row = find.text(title).first;
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  Future<void> submitInput(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, 'Submit'));
    await tester.pumpAndSettle();
  }

  Future<void> editInput(
    WidgetTester tester,
    String title,
    String value,
  ) async {
    await openInput(tester, title);
    await tester.enterText(find.byType(TextFormField), value);
    await submitInput(tester);
  }

  testWidgets('shows the matched policy and clears results after edits', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text('Source'), findsOneWidget);
    expect(find.text('Destination'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
    expect(find.byType(DecorationListItem), findsNWidgets(4));
    expect(find.byType(TextFormField), findsNothing);
    await editInput(tester, 'Domain or IP address', 'example.com');
    await query(tester);
    await tester.scrollUntilVisible(
      find.text('Domain'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Domain'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Proxy → node-a'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Proxy → node-a'), findsOneWidget);
    verify(
      () => handler.ruleLookup(
        target: 'example.com',
        sourcePort: 0,
        destinationPort: 443,
        network: 'tcp',
      ),
    ).called(1);
    await editInput(tester, 'Domain or IP address', 'example.org');
    expect(find.text('Proxy → node-a'), findsNothing);
  });

  testWidgets('rejects URLs and invalid destination ports in input dialogs', (
    tester,
  ) async {
    await mount(tester);
    await openInput(tester, 'Domain or IP address');
    await tester.enterText(find.byType(TextFormField), 'https://example.com');
    await submitInput(tester);
    expect(
      find.text('Enter a valid domain or IP address without a URL or port'),
      findsOneWidget,
    );
    expect(find.byType(InputDialog), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '2001:db8::1');
    await submitInput(tester);
    await openInput(tester, 'Destination port');
    await tester.enterText(find.byType(TextFormField), '65536');
    await submitInput(tester);
    expect(find.text('Enter a port between 1 and 65535'), findsOneWidget);
    expect(find.byType(InputDialog), findsOneWidget);
    verifyNever(
      () => handler.ruleLookup(
        target: any(named: 'target'),
        sourcePort: any(named: 'sourcePort'),
        destinationPort: any(named: 'destinationPort'),
        network: any(named: 'network'),
      ),
    );
  });

  testWidgets(
    'uses a radio dialog and sends distinct source and destination ports',
    (tester) async {
      await mount(tester);
      expect(find.text('Source port'), findsOneWidget);
      expect(find.text('Destination port'), findsOneWidget);
      await editInput(tester, 'Domain or IP address', 'example.com');
      await editInput(tester, 'Source port', '54321');
      await editInput(tester, 'Destination port', '8443');
      await tester.ensureVisible(find.text('TCP'));
      await tester.tap(find.text('TCP'));
      await tester.pumpAndSettle();
      expect(find.byType(Radio<(String,)>), findsNWidgets(2));
      await tester.tap(find.text('UDP'));
      await tester.pumpAndSettle();
      expect(find.byType(CommonDialog), findsNothing);
      await query(tester);
      verify(
        () => handler.ruleLookup(
          target: 'example.com',
          sourcePort: 54321,
          destinationPort: 8443,
          network: 'udp',
        ),
      ).called(1);
      await tester.scrollUntilVisible(
        find.text('Domain'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.scrollUntilVisible(
        find.text('UDP'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('UDP'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TCP').last);
      await tester.pumpAndSettle();
      expect(find.text('Domain'), findsNothing);
    },
  );

  testWidgets('rejects invalid source ports before querying', (tester) async {
    await mount(tester);
    await editInput(tester, 'Domain or IP address', 'example.com');
    await openInput(tester, 'Source port');
    for (final port in ['0', '65536', '0xff']) {
      await tester.enterText(find.byType(TextFormField), port);
      await submitInput(tester);
      expect(find.text('Enter a port between 1 and 65535'), findsOneWidget);
    }
    verifyNever(
      () => handler.ruleLookup(
        target: any(named: 'target'),
        sourcePort: any(named: 'sourcePort'),
        destinationPort: any(named: 'destinationPort'),
        network: any(named: 'network'),
      ),
    );
  });

  testWidgets('disables queries until the core is connected', (tester) async {
    final container = await mount(tester, connected: false);
    final queryButton = find.widgetWithText(FilledButton, 'Check route');
    expect(queryButton, findsOneWidget);
    expect(tester.widget<FilledButton>(queryButton).onPressed, isNull);
    expect(
      find.text('Connect the core before checking a route'),
      findsOneWidget,
    );
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    await tester.pump();
    expect(tester.widget<FilledButton>(queryButton).onPressed, isNotNull);
  });

  testWidgets('keeps cancelled edits and allows clearing the source port', (
    tester,
  ) async {
    await mount(tester);
    await query(tester);
    expect(
      find.text('Enter a valid domain or IP address without a URL or port'),
      findsOneWidget,
    );
    await editInput(tester, 'Domain or IP address', 'example.com');
    await editInput(tester, 'Source port', '54321');
    await openInput(tester, 'Domain or IP address');
    await tester.enterText(find.byType(TextFormField), 'example.org');
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('example.com'), findsOneWidget);
    expect(find.text('example.org'), findsNothing);
    await editInput(tester, 'Source port', '');
    expect(find.text('Optional; leave blank if unknown'), findsOneWidget);
    await query(tester);
    verify(
      () => handler.ruleLookup(
        target: 'example.com',
        sourcePort: 0,
        destinationPort: 443,
        network: 'tcp',
      ),
    ).called(1);
  });

  testWidgets('releases loading state after failure and permits retry', (
    tester,
  ) async {
    final pending = Completer<RuleLookupResult>();
    when(
      () => handler.ruleLookup(
        target: 'example.com',
        sourcePort: 0,
        destinationPort: 443,
        network: 'tcp',
      ),
    ).thenAnswer((_) => pending.future);
    await mount(tester);
    await editInput(tester, 'Domain or IP address', 'example.com');
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
      () => handler.ruleLookup(
        target: 'example.com',
        sourcePort: 0,
        destinationPort: 443,
        network: 'tcp',
      ),
    ).thenAnswer((_) async => _result);
    await query(tester);
    await tester.scrollUntilVisible(
      find.text('Proxy → node-a'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Proxy → node-a'), findsOneWidget);
  });

  testWidgets('ignores completion after the page is disposed', (tester) async {
    final pending = Completer<RuleLookupResult>();
    when(
      () => handler.ruleLookup(
        target: 'example.com',
        sourcePort: 0,
        destinationPort: 443,
        network: 'tcp',
      ),
    ).thenAnswer((_) => pending.future);
    await mount(tester);
    await editInput(tester, 'Domain or IP address', 'example.com');
    await query(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(_result);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
