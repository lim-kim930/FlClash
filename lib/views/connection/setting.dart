import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

class ConnectionsSetting extends StatelessWidget {
  final ValueNotifier<TrackerInfosState> stateNotifier;

  const ConnectionsSetting({super.key, required this.stateNotifier});

  IconData _getIconWithConnectionsSortType(ConnectionsSortType type) {
    return switch (type) {
      ConnectionsSortType.none => Icons.sort,
      ConnectionsSortType.host => Icons.link,
      ConnectionsSortType.download => Icons.download,
      ConnectionsSortType.downloadSpeed => Icons.keyboard_double_arrow_down,
      ConnectionsSortType.upload => Icons.upload,
      ConnectionsSortType.uploadSpeed => Icons.keyboard_double_arrow_up,
      ConnectionsSortType.connectTime => Icons.access_time,
    };
  }

  String _getStringConnectionsSortType(BuildContext context, ConnectionsSortType type) {
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
                        iconData: _getIconWithConnectionsSortType(item),
                      ),
                      isSelected: sortType == item,
                      onPressed: () {
                        stateNotifier.value = stateNotifier.value.copyWith(sortType: item);
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
                      iconData: Icons.arrow_upward,
                    ),
                    isSelected: sortDirection == SortDirection.asc,
                    onPressed: () {
                      stateNotifier.value = stateNotifier.value.copyWith(sortDirection: SortDirection.asc);
                    },
                  ),
                  SettingInfoCard(
                    Info(
                      label: appLocalizations.sortDesc,
                      iconData: Icons.arrow_downward,
                    ),
                    isSelected: sortDirection == SortDirection.desc,
                    onPressed: () {
                      stateNotifier.value = stateNotifier.value.copyWith(sortDirection: SortDirection.desc);
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
