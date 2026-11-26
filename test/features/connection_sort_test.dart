import 'dart:async';
import 'dart:math';

import 'package:fl_clash/features/connection/connection_rows.dart';
import 'package:fl_clash/features/connection/connection_sort.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final _start = DateTime.utc(2026, 11, 21);

TrackerInfo _connection(String id, int download, {int second = 0}) =>
    TrackerInfo(
      id: id,
      download: download,
      start: _start.add(Duration(seconds: second)),
      metadata: Metadata(network: 'tcp', host: '$id.test'),
      chains: const ['Proxy'],
      rule: 'MATCH',
      rulePayload: '',
    );

List<String> _topFirst(MinuteRows<String> rows) => [
  for (var index = rows.length - 1; index >= 0; index--)
    if (rows.rowAt(index) case MinuteRecord(:final item)) item,
];

Future<List<int>> _sort(RecordSortInput input) async =>
    recordSortIndexes(input);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConnectionRows rows;
  late ConnectionSorter sorter;
  late ConnectionLog log;

  setUp(() {
    log = ConnectionLog(10).open([
      _connection('a', 10),
      _connection('b', 30, second: 1),
      _connection('c', 30, second: 2),
    ]);
    rows = ConnectionRows()..follow(log);
    sorter = ConnectionSorter(source: rows, sortIndexes: _sort);
  });

  tearDown(() {
    sorter.dispose();
    rows.dispose();
  });

  test(
    'default ordering keeps the minute headers and does no sort work',
    () async {
      var calls = 0;
      final untouched = ConnectionSorter(
        source: rows,
        sortIndexes: (input) async {
          calls++;
          return recordSortIndexes(input);
        },
      );
      addTearDown(untouched.dispose);

      await untouched.refresh();

      expect(untouched.rows, same(rows));
      expect(rows.rowAt(rows.length - 1), isA<MinuteHeader<String>>());
      expect(calls, 0);
    },
  );

  test(
    'sort direction changes while equal amounts keep newest first',
    () async {
      await sorter.setSort((columnId: 'download', descending: true));
      expect(_topFirst(sorter.rows), ['c', 'b', 'a']);
      expect(sorter.rows.length, 3);

      await sorter.setSort((columnId: 'download', descending: false));
      expect(_topFirst(sorter.rows), ['a', 'c', 'b']);
      expect(sorter.rows.indexOfKey(const ValueKey('a')), 2);
      expect(sorter.atFraction(1)?.id, 'a');

      await sorter.setSort(null);
      expect(sorter.rows, same(rows));
    },
  );

  test(
    'new samples reorder the shown connections without reopening history',
    () async {
      await sorter.setSort((columnId: 'download', descending: true));
      log = log.updateTraffic({'a': (upload: 0, download: 100)});
      rows.update(log);
      await sorter.refresh();
      expect(_topFirst(sorter.rows), ['a', 'c', 'b']);

      log = log.close(['a'], _start.add(const Duration(seconds: 10)));
      rows.update(log);
      await sorter.refresh();
      expect(_topFirst(sorter.rows), ['a', 'c', 'b']);
      expect(rows.infoOf('a').download, 100);
      expect(rows.infoOf('a').isActive, isFalse);
    },
  );

  test(
    'filtering and clearing remove stale row keys before a sort completes',
    () async {
      await sorter.setSort((columnId: 'download', descending: true));
      rows.showWhere((info) => info.id != 'b');
      final filtered = sorter.refresh();
      expect(sorter.rows.indexOfKey(const ValueKey('b')), isNull);
      await filtered;
      expect(_topFirst(sorter.rows), ['c', 'a']);

      rows.follow(ConnectionLog(10));
      final cleared = sorter.refresh();
      expect(sorter.rows.length, 0);
      await cleared;
      expect(sorter.atFraction(0), isNull);
    },
  );

  test(
    'a pointer resting on the list holds its order while totals change',
    () async {
      await sorter.setSort((columnId: 'download', descending: true));
      rows.hovered = true;
      log = log.updateTraffic({'a': (upload: 0, download: 100)});
      rows.update(log);
      await sorter.refresh();
      expect(_topFirst(sorter.rows), ['c', 'b', 'a']);
      expect(rows.infoOf('a').download, 100);

      rows.hovered = false;
      await sorter.refresh();
      expect(_topFirst(sorter.rows), ['a', 'c', 'b']);
    },
  );

  test('an older sort cannot overwrite a newer choice', () async {
    final started = [Completer<void>(), Completer<void>()];
    final results = [Completer<List<int>>(), Completer<List<int>>()];
    var calls = 0;
    final delayed = ConnectionSorter(
      source: rows,
      sortIndexes: (input) {
        final call = calls++;
        started[call].complete();
        return results[call].future;
      },
    );
    addTearDown(delayed.dispose);

    final old = delayed.setSort((columnId: 'download', descending: true));
    await started[0].future;
    final current = delayed.setSort((columnId: 'download', descending: false));
    await started[1].future;
    results[1].complete([2, 0, 1]);
    await current;
    results[0].complete([0, 1, 2]);
    await old;

    expect(_topFirst(delayed.rows), ['a', 'c', 'b']);
    expect(delayed.choice.value, (columnId: 'download', descending: false));
    expect(delayed.changing.value, isFalse);
  });

  test(
    'a failed sort releases progress and restores the default ordering',
    () async {
      final failed = ConnectionSorter(
        source: rows,
        sortIndexes: (input) async => throw StateError('sort failed'),
      );
      addTearDown(failed.dispose);

      await expectLater(
        failed.setSort((columnId: 'download', descending: true)),
        throwsStateError,
      );

      expect(failed.choice.value, isNull);
      expect(failed.changing.value, isFalse);
      expect(failed.rows, same(rows));
    },
  );

  test('a sort that finishes after disposal publishes nothing', () async {
    final started = Completer<void>();
    final result = Completer<List<int>>();
    final delayed = ConnectionSorter(
      source: rows,
      sortIndexes: (input) {
        started.complete();
        return result.future;
      },
    );
    var published = 0;
    delayed.addListener(() => published++);
    final work = delayed.setSort((columnId: 'download', descending: true));
    await started.future;
    final before = published;
    delayed.dispose();
    result.complete([0, 1, 2]);
    await work;
    expect(published, before);
  });

  test(
    'the isolate sorts 20000 records with stable ties and valid row keys',
    () async {
      final random = Random(95);
      final many = ConnectionLog(20000).open([
        for (var index = 0; index < 20000; index++)
          _connection('c$index', random.nextInt(100), second: index),
      ]);
      final source = ConnectionRows()..follow(many);
      final isolated = ConnectionSorter(source: source);
      addTearDown(source.dispose);
      addTearDown(isolated.dispose);

      await isolated.setSort((columnId: 'download', descending: true));

      final ids = _topFirst(isolated.rows);
      expect(ids.length, 20000);
      expect(ids.toSet().length, 20000);
      for (var index = 1; index < ids.length; index++) {
        final before = source.infoOf(ids[index - 1]);
        final after = source.infoOf(ids[index]);
        expect(before.download, greaterThanOrEqualTo(after.download));
        if (before.download == after.download) {
          expect(before.start.isAfter(after.start), isTrue);
        }
      }
      expect(isolated.rows.indexOfKey(ValueKey(ids.first)), 19999);
    },
  );
}
