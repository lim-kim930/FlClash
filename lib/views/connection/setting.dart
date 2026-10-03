import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/icons/icons.dart';
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

  List<Widget> _buildSortSetting(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return generateSection(
      isFirst: true,
      title: appLocalizations.sort,
      items: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          child: ValueListenableBuilder<TrackerInfosState>(
            valueListenable: stateNotifier,
            builder: (_, state, _) {
              final sortType = state.sortType;
              return Wrap(
                spacing: 16,
                children: [
                  for (final item in ConnectionsSortType.values)
                    SettingInfoCard(
                      Info(
                        label: _getStringConnectionsSortType(context, item),
                        glyph: _getGlyphWithConnectionsSortType(item),
                      ),
                      isSelected: sortType == item,
                      onPressed: () {
                        stateNotifier.value = stateNotifier.value.copyWith(
                          sortType: item,
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSortDirectionSetting(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return generateSection(
      title: '',
      items: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          child: ValueListenableBuilder<TrackerInfosState>(
            valueListenable: stateNotifier,
            builder: (_, state, _) {
              final sortDirection = state.sortDirection;
              return Wrap(
                spacing: 16,
                children: [
                  SettingInfoCard(
                    Info(
                      label: appLocalizations.sortAsc,
                      glyph: AppGlyphs.arrowUp,
                    ),
                    isSelected: sortDirection == SortDirection.asc,
                    onPressed: () {
                      stateNotifier.value = stateNotifier.value.copyWith(
                        sortDirection: SortDirection.asc,
                      );
                    },
                  ),
                  SettingInfoCard(
                    Info(
                      label: appLocalizations.sortDesc,
                      glyph: AppGlyphs.arrowDown,
                    ),
                    isSelected: sortDirection == SortDirection.desc,
                    onPressed: () {
                      stateNotifier.value = stateNotifier.value.copyWith(
                        sortDirection: SortDirection.desc,
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._buildSortSetting(context),
          ..._buildSortDirectionSetting(context),
        ],
      ),
    );
  }
}
