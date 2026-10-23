import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/connection/connections.dart';
import 'package:fl_clash/views/connection/setting.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_app.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    globalState.container = container;
  });

  tearDown(() {
    container.dispose();
  });

  for (final type in [SheetType.sideSheet, SheetType.bottomSheet]) {
    testWidgets('connection settings clear the $type title bar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = ValueNotifier<RecordSort?>((
        columnId: 'downloadSpeed',
        descending: true,
      ));
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _TestApp(
            child: SheetProvider(
              type: type,
              child: CommonScaffold(
                title: 'Settings',
                body: Builder(
                  builder: (context) => ConnectionsSetting(
                    sortController: settings,
                    columns: trackerInfoColumns(
                      context,
                      width: double.infinity,
                      isLive: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byType(ListHeader).first).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.byType(AppBar)).dy),
      );
      expect(find.text('Sort by'), findsOneWidget);
      expect(find.text('Sort direction'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Scrollable && widget.axis == Axis.horizontal,
        ),
        findsNothing,
      );
      await tester.tap(find.text('Sort by'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Target'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Target'));
      await tester.pumpAndSettle();
      expect(settings.value?.columnId, 'target');
      await tester.tap(find.text('Sort direction'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ascending'));
      await tester.pumpAndSettle();
      expect(settings.value?.descending, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  List<TrackerInfo> buildConnections(int count) {
    return List.generate(
      count,
      (index) => TrackerInfo(
        id: '$index',
        start: DateTime(2024),
        metadata: Metadata(
          network: 'tcp',
          host: 'host-$index.com',
          destinationPort: '443',
        ),
        chains: const ['proxy-a'],
        rule: 'MATCH',
        rulePayload: '',
      ),
    );
  }

  Future<void> pumpConnections(
    WidgetTester tester, {
    required Future<List<TrackerInfo>> Function() connectionsReader,
    bool isPageActive = true,
    bool inSheet = false,
  }) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _TestApp(
          child: PageActivityScope(
            isActive: isPageActive,
            child: inSheet
                ? SheetProvider(
                    type: SheetType.page,
                    child: NestedPagedSheet(
                      builder: (_) =>
                          ConnectionsView(connectionsReader: connectionsReader),
                    ),
                  )
                : ConnectionsView(connectionsReader: connectionsReader),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final inSheet in [false, true]) {
    testWidgets('live details keep polling with inSheet=$inSheet', (
      tester,
    ) async {
      var reads = 0;
      var snapshot = [
        buildConnections(1).single.copyWith(upload: 100, download: 200),
      ];
      await pumpConnections(
        tester,
        inSheet: inSheet,
        connectionsReader: () async {
          reads++;
          return snapshot;
        },
      );
      await tester.pump();
      await tester.tap(find.byType(TrackerInfoItem).first);
      await tester.pumpAndSettle();
      final beforePoll = reads;
      snapshot = [snapshot.single.copyWith(upload: 1124, download: 2248)];
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      final detail = tester.widget<TrackerInfoDetailView>(
        find.byType(TrackerInfoDetailView),
      );
      expect(detail.trackerInfo.upload, 1124);
      expect(detail.trackerInfo.download, 2248);
      expect(detail.trackerInfo.uploadSpeed, isNonNegative);
      expect(reads, beforePoll + 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(commonDuration);
    });
  }

  testWidgets('closed details retain the last totals and stop polling', (
    tester,
  ) async {
    var snapshot = [buildConnections(1).single];
    var reads = 0;
    await pumpConnections(
      tester,
      connectionsReader: () async {
        reads++;
        return snapshot;
      },
    );
    await tester.pump();
    await tester.tap(find.byType(TrackerInfoItem).first);
    await tester.pumpAndSettle();
    snapshot = [snapshot.single.copyWith(upload: 2048, download: 4096)];
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    snapshot = [];
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    final detail = tester.widget<TrackerInfoDetailView>(
      find.byType(TrackerInfoDetailView),
    );
    expect(detail.trackerInfo.upload, 2048);
    expect(detail.trackerInfo.download, 4096);
    expect(detail.trackerInfo.uploadSpeed, 0);
    expect(detail.trackerInfo.downloadSpeed, 0);
    final afterClose = reads;
    await tester.pump(const Duration(seconds: 3));
    expect(reads, afterClose);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(commonDuration);
  });

  testWidgets('closing details resumes polling the connection list', (
    tester,
  ) async {
    var reads = 0;
    await pumpConnections(
      tester,
      connectionsReader: () async {
        reads++;
        return buildConnections(1);
      },
    );
    await tester.pump();
    await tester.tap(find.byType(TrackerInfoItem).first);
    await tester.pumpAndSettle();
    final beforeClose = reads;
    Navigator.of(tester.element(find.byType(TrackerInfoDetailView))).pop();
    await tester.pumpAndSettle();
    expect(reads, greaterThan(beforeClose));
    expect(find.byType(TrackerInfoDetailView), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(commonDuration);
  });

  testWidgets('details retry a failed read without losing the last snapshot', (
    tester,
  ) async {
    var fail = false;
    var snapshot = [buildConnections(1).single.copyWith(download: 1024)];
    await pumpConnections(
      tester,
      connectionsReader: () async {
        if (fail) throw StateError('temporary read failure');
        return snapshot;
      },
    );
    await tester.pump();
    await tester.tap(find.byType(TrackerInfoItem).first);
    await tester.pumpAndSettle();
    fail = true;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(
      tester
          .widget<TrackerInfoDetailView>(find.byType(TrackerInfoDetailView))
          .trackerInfo
          .download,
      1024,
    );
    expect(tester.takeException(), isNull);
    fail = false;
    snapshot = [snapshot.single.copyWith(download: 2048)];
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(
      tester
          .widget<TrackerInfoDetailView>(find.byType(TrackerInfoDetailView))
          .trackerInfo
          .download,
      2048,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(commonDuration);
  });

  testWidgets('table, settings and narrow lists share the same sort', (
    tester,
  ) async {
    final connections = buildConnections(2);
    await pumpConnections(tester, connectionsReader: () async => connections);
    tester.view.physicalSize = const Size(1400, 1000);
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download').first);
    await tester.pump();
    final controller = tester
        .widget<RecordTableFrame<TrackerInfo>>(
          find.byType(RecordTableFrame<TrackerInfo>),
        )
        .sortController!;
    expect(controller.value, (columnId: 'downloadSpeed', descending: true));

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sort by'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Target').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Target').last);
    await tester.pumpAndSettle();
    expect(controller.value?.columnId, 'target');
    await tester.tap(find.text('Sort direction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ascending').last);
    await tester.pumpAndSettle();
    expect(controller.value, (columnId: 'target', descending: false));
    Navigator.of(tester.element(find.byType(ConnectionsSetting))).pop();
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(600, 800);
    await tester.pumpAndSettle();
    final sorted = tester.widget<TrackerInfoAnimatedList>(
      find.byType(TrackerInfoAnimatedList),
    );
    expect(sorted.trackerInfos.map((info) => info.id), ['0', '1']);
    controller.value = (columnId: 'target', descending: true);
    await tester.pump();
    final reversed = tester.widget<TrackerInfoAnimatedList>(
      find.byType(TrackerInfoAnimatedList),
    );
    expect(reversed.trackerInfos.map((info) => info.id), ['1', '0']);
    controller.value = null;
    await tester.pump();
    final restored = tester.widget<TrackerInfoAnimatedList>(
      find.byType(TrackerInfoAnimatedList),
    );
    expect(restored.trackerInfos.map((info) => info.id), ['0', '1']);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(commonDuration);
  });

  testWidgets('ConnectionsView lazily builds every connection', (tester) async {
    final connections = buildConnections(100);

    await pumpConnections(tester, connectionsReader: () async => connections);
    await tester.pump(const Duration(seconds: 1));

    final builtItems = find.byType(TrackerInfoItem).evaluate().length;
    expect(builtItems, greaterThan(0));
    expect(builtItems, lessThan(connections.length));
    expect(find.textContaining('host-0.com'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('host-99.com'),
      800,
      scrollable: find
          .descendant(
            of: find.byType(TrackerInfoAnimatedList),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    expect(find.textContaining('host-99.com'), findsOneWidget);
    expect(tester.takeException(), null);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a row blocks its own connection and refreshes the list', (
    tester,
  ) async {
    final core = _MockCoreHandlerInterface();
    when(() => core.closeConnection(any())).thenAnswer((_) async => true);
    container.dispose();
    container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
      ],
    );
    globalState.container = container;
    var connections = buildConnections(2);
    var readCount = 0;

    await pumpConnections(
      tester,
      connectionsReader: () async {
        readCount++;
        return connections;
      },
    );
    await tester.pump(const Duration(seconds: 1));
    final reads = readCount;
    connections = connections.sublist(1);

    await tester.tap(find.byTooltip('Block connection').first);
    await tester.pumpAndSettle();

    verify(() => core.closeConnection('0')).called(1);
    expect(readCount, greaterThan(reads));
    expect(find.textContaining('host-0.com'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a wide table shows its whole protocol header', (tester) async {
    await pumpConnections(
      tester,
      connectionsReader: () async => buildConnections(2),
    );
    tester.view.physicalSize = const Size(1600, 900);
    await tester.pump(const Duration(seconds: 1));

    final header = tester.renderObject<RenderParagraph>(find.text('Protocol'));
    expect(header.didExceedMaxLines, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ConnectionsView polls only while the page is active', (
    tester,
  ) async {
    var readCount = 0;

    Future<List<TrackerInfo>> readConnections() async {
      readCount++;
      return const [];
    }

    await pumpConnections(
      tester,
      connectionsReader: readConnections,
      isPageActive: false,
    );
    await tester.pump(const Duration(seconds: 3));

    expect(readCount, 0);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _TestApp(
          child: PageActivityScope(
            isActive: true,
            child: ConnectionsView(connectionsReader: readConnections),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(readCount, 1);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(readCount, 2);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _TestApp(
          child: PageActivityScope(
            isActive: false,
            child: ConnectionsView(connectionsReader: readConnections),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));

    expect(readCount, 2);
    expect(tester.takeException(), null);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ConnectionsView stops polling while the app is paused', (
    tester,
  ) async {
    var readCount = 0;

    Future<List<TrackerInfo>> readConnections() async {
      readCount++;
      return const [];
    }

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpConnections(tester, connectionsReader: readConnections);
    await tester.pump();

    expect(readCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 4));

    expect(readCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(readCount, 2);
    expect(tester.takeException(), null);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _TestApp extends StatelessWidget {
  final Widget child;

  const _TestApp({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: globalState.navigatorKey,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        AppUiLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      builder: (context, child) {
        return wrapAppScopes(context, child!);
      },
      home: child,
    );
  }
}

class _MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}
