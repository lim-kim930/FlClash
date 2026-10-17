import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

class ConnectionsSetting extends StatelessWidget {
  final ValueNotifier<TrackerInfosState> stateNotifier;

  const ConnectionsSetting({super.key, required this.stateNotifier});

  Glyph _getGlyphWithConnectionsSortType(ConnectionsSortType type) {
    return switch (type) {
      ConnectionsSortType.none => AppGlyphs.sort,
      ConnectionsSortType.host => AppGlyphs.link,
      ConnectionsSortType.download => AppGlyphs.arrowDown,
      ConnectionsSortType.downloadSpeed => AppGlyphs.arrowDown,
      ConnectionsSortType.upload => AppGlyphs.upload,
      ConnectionsSortType.uploadSpeed => AppGlyphs.arrowUp,
      ConnectionsSortType.connectTime => AppGlyphs.clock,
    };
  }

  String _getStringConnectionsSortType(
    BuildContext context,
    ConnectionsSortType type,
  ) {
    final appLocalizations = context.appLocalizations;
    return switch (type) {
      ConnectionsSortType.none => appLocalizations.defaultText,
      ConnectionsSortType.host => appLocalizations.host,
      ConnectionsSortType.download => appLocalizations.download,
      ConnectionsSortType.downloadSpeed => appLocalizations.downloadSpeed,
      ConnectionsSortType.upload => appLocalizations.upload,
      ConnectionsSortType.uploadSpeed => appLocalizations.uploadSpeed,
      ConnectionsSortType.connectTime => appLocalizations.time,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: context.contentTopPadding, bottom: 32),
      child: ValueListenableBuilder<TrackerInfosState>(
        valueListenable: stateNotifier,
        builder: (_, state, _) => generateSection(
          title: l.settings,
          items: [
            ListItem<ConnectionsSortType>.options(
              leading: GlyphIcon(
                _getGlyphWithConnectionsSortType(state.sortType),
              ),
              title: Text(l.sortBy),
              options: ConnectionsSortType.values,
              value: state.sortType,
              textBuilder: (value) =>
                  _getStringConnectionsSortType(context, value),
              onChanged: (value) {
                stateNotifier.value = stateNotifier.value.copyWith(
                  sortType: value,
                );
              },
            ),
            ListItem<SortDirection>.options(
              leading: GlyphIcon(
                state.sortDirection == SortDirection.asc
                    ? AppGlyphs.arrowUp
                    : AppGlyphs.arrowDown,
              ),
              title: Text(l.sortDirection),
              options: SortDirection.values,
              value: state.sortDirection,
              textBuilder: (value) =>
                  value == SortDirection.asc ? l.sortAsc : l.sortDesc,
              onChanged: (value) {
                stateNotifier.value = stateNotifier.value.copyWith(
                  sortDirection: value,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
