import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/foundation.dart';

import 'connection_rows.dart';

Future<List<int>> _sortIndexes(RecordSortInput input) =>
    compute(recordSortIndexes, input, debugLabel: 'connectionSort');

Comparable<Object> _sortKey(TrackerInfo info, String columnId, DateTime now) =>
    switch (columnId) {
      'start' => info.start.microsecondsSinceEpoch,
      'download' => info.download,
      'upload' => info.upload,
      'traffic' => info.upload + info.download,
      'downloadSpeed' => info.downloadSpeed ?? 0,
      'uploadSpeed' => info.uploadSpeed ?? 0,
      'host' => info.title.toLowerCase(),
      'process' => info.metadata.process.toLowerCase(),
      'network' => info.metadata.network.toLowerCase(),
      'rule' => '${info.rule} ${info.rulePayload}'.toLowerCase(),
      'exit' => (info.chains.lastOrNull ?? '').toLowerCase(),
      'duration' => (info.endedAt ?? now).difference(info.start).inMicroseconds,
      _ => throw ArgumentError.value(columnId, 'columnId'),
    };

class _SortedConnectionRows implements MinuteRows<String> {
  final List<String> _ids;
  Map<String, int>? _indexes;

  _SortedConnectionRows(this._ids);

  _SortedConnectionRows retaining(List<String> oldestFirst) {
    final present = oldestFirst.toSet();
    final previous = _ids.toSet();
    return _SortedConnectionRows([
      for (final id in oldestFirst.reversed)
        if (!previous.contains(id)) id,
      for (final id in _ids)
        if (present.contains(id)) id,
    ]);
  }

  String? atFraction(double fraction) =>
      _ids.isEmpty ? null : _ids[((1 - fraction) * (_ids.length - 1)).round()];

  @override
  int get length => _ids.length;

  @override
  MinuteRow<String> rowAt(int index) => MinuteRecord(
    _ids[_ids.length - 1 - index],
    ItemPosition.get(_ids.length - 1 - index, _ids.length),
  );

  @override
  Key keyOf(String id) => ValueKey(id);

  @override
  int? indexOfKey(Key key) => key is ValueKey<String>
      ? (_indexes ??= {
          for (final (index, id) in _ids.indexed) id: _ids.length - 1 - index,
        })[key.value]
      : null;
}

class ConnectionSorter extends ChangeNotifier {
  final ConnectionRows source;
  final Future<List<int>> Function(RecordSortInput) sortIndexes;
  final _choice = ValueNotifier<RecordSort?>(null);
  final _changing = ValueNotifier(false);
  _SortedConnectionRows? _sorted;
  List<String>? _sourceIds;
  var _generation = 0;
  var _disposed = false;

  ConnectionSorter({
    required this.source,
    Future<List<int>> Function(RecordSortInput)? sortIndexes,
  }) : sortIndexes = sortIndexes ?? _sortIndexes;

  ValueListenable<RecordSort?> get choice => _choice;

  ValueListenable<bool> get changing => _changing;

  MinuteRows<String> get rows => _sorted ?? source;

  TrackerInfo? atFraction(double fraction) => _sorted == null
      ? source.atFraction(fraction)
      : switch (_sorted!.atFraction(fraction)) {
          final id? => source.heldInfoOf(id),
          null => null,
        };

  Future<void> setSort(RecordSort? sort) async {
    if (_choice.value == sort) return;
    _choice.value = sort;
    if (sort == null) {
      _generation++;
      _sorted = null;
      _sourceIds = null;
      _changing.value = false;
      notifyListeners();
      return;
    }
    _changing.value = true;
    await refresh(force: true);
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  Future<void> refresh({bool force = false}) async {
    final sort = _choice.value;
    if (_disposed || sort == null) return;
    final generation = ++_generation;
    final ids = source.shownIds;
    if (!identical(ids, _sourceIds)) {
      _sorted = _sorted?.retaining(ids);
      _sourceIds = ids;
      notifyListeners();
    }
    if (source.holdsNew && !force && !_changing.value) return;
    await whenNothingAnimates(besides: _changing.value ? 1 : 0);
    if (!_current(generation)) return;
    final newestFirst = ids.reversed.toList(growable: false);
    final now = DateTime.now();
    try {
      final order = await sortIndexes((
        keys: [
          for (final id in newestFirst)
            _sortKey(source.infoOf(id), sort.columnId, now),
        ],
        descending: sort.descending,
      ));
      if (!_current(generation)) return;
      _sorted = _SortedConnectionRows([
        for (final index in order) newestFirst[index],
      ]);
      notifyListeners();
    } catch (_) {
      if (!_current(generation)) return;
      _choice.value = null;
      _sorted = null;
      notifyListeners();
      rethrow;
    } finally {
      if (_current(generation)) _changing.value = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _choice.dispose();
    _changing.dispose();
    super.dispose();
  }
}
