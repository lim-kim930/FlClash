import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tracker_speed_ranker.dart';

String _ruleText(TrackerInfo trackerInfo) {
  final rule = trackerInfo.rule;
  final rulePayload = trackerInfo.rulePayload;
  if (rulePayload.isNotEmpty) {
    return '$rule($rulePayload)';
  }
  return rule;
}

String _endpointText(String ip, String port) {
  if (ip.isEmpty) {
    return '';
  }
  if (port.isNotEmpty) {
    return '$ip:$port';
  }
  return ip;
}

Future<void> showTrackerInfoDetail(
  BuildContext context,
  TrackerInfo trackerInfo,
  String title, {
  Future<List<TrackerInfo>?> Function()? connectionsReader,
}) async {
  await showInSheet<void>(
    context,
    builder: (_) => CommonScaffold(
      title: title,
      body: connectionsReader == null
          ? TrackerInfoDetailView(trackerInfo: trackerInfo)
          : _LiveTrackerInfoDetailView(
              trackerInfo: trackerInfo,
              connectionsReader: connectionsReader,
            ),
    ),
  );
}

class _LiveTrackerInfoDetailView extends StatefulWidget {
  const _LiveTrackerInfoDetailView({
    required this.trackerInfo,
    required this.connectionsReader,
  });

  final TrackerInfo trackerInfo;
  final Future<List<TrackerInfo>?> Function() connectionsReader;

  @override
  State<_LiveTrackerInfoDetailView> createState() =>
      _LiveTrackerInfoDetailViewState();
}

class _LiveTrackerInfoDetailViewState extends State<_LiveTrackerInfoDetailView>
    with
        WidgetsBindingObserver,
        ActivePollingMixin<_LiveTrackerInfoDetailView> {
  final _speedRanker = TrackerSpeedRanker();
  late TrackerInfo _trackerInfo;
  bool _closed = false;

  @override
  Duration get pollInterval => const Duration(seconds: 1);

  @override
  bool get pollOnStart => false;

  @override
  bool get canPoll => super.canPoll && !_closed;

  @override
  void initState() {
    super.initState();
    _trackerInfo = widget.trackerInfo;
    _speedRanker.rank([_trackerInfo], DateTime.now());
  }

  @override
  Future<void> poll(PollGuard isCurrent) async {
    final infos = await widget.connectionsReader();
    if (!isCurrent() || infos == null) return;
    final current = infos
        .where((info) => info.id == _trackerInfo.id)
        .firstOrNull;
    if (current == null) {
      setState(() {
        _closed = true;
        _trackerInfo = _trackerInfo.copyWith(uploadSpeed: 0, downloadSpeed: 0);
      });
      stopPolling();
      return;
    }
    final next = _speedRanker.rank([current], DateTime.now()).single;
    setState(() => _trackerInfo = next);
  }

  @override
  Widget build(BuildContext context) =>
      TrackerInfoDetailView(trackerInfo: _trackerInfo);
}

class TrackerInfoItem extends ConsumerWidget {
  final TrackerInfo trackerInfo;
  final bool isLive;
  final Function(String)? onClickKeyword;
  final Widget? action;
  final String detailTitle;
  final ValueChanged<TrackerInfo>? onShowDetails;

  const TrackerInfoItem({
    super.key,
    required this.trackerInfo,
    this.isLive = false,
    this.onClickKeyword,
    this.action,
    required this.detailTitle,
    this.onShowDetails,
  });

  @override
  Widget build(BuildContext context, ref) {
    final showIcon = ref.watch(
      patchClashConfigProvider.select(
        (state) =>
            state.findProcessMode == FindProcessMode.always && system.isAndroid,
      ),
    );
    return RecordListItem(
      onTap: () {
        final showDetails = onShowDetails;
        if (showDetails != null) {
          showDetails(trackerInfo);
        } else {
          showTrackerInfoDetail(context, trackerInfo, detailTitle);
        }
      },
      header: _buildHeader(context),
      body: _TrackerInfoBody(
        trackerInfo: trackerInfo,
        showIcon: showIcon,
        onClickKeyword: onClickKeyword,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final network = Text(
      trackerInfo.metadata.network.toUpperCase(),
      style: AppTextStyle.caption1
          .of(context, emphasized: true)
          .copyWith(color: context.colorScheme.onSurfaceVariant),
    );
    if (!isLive) {
      return RecordHeader(
        trailing: action,
        children: [RecordTimestamp(trackerInfo.start.showFull), network],
      );
    }
    final color = context.colorScheme.onSurfaceVariant;
    WidgetSpan arrow(Glyph glyph) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: GlyphIcon(glyph, size: 12, color: color),
    );
    return RecordHeader(
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Text.rich(
            TextSpan(
              children: [
                arrow(AppGlyphs.arrowUp),
                TextSpan(
                  text: ' ${(trackerInfo.uploadSpeed ?? 0).traffic.show}/s   ',
                ),
                arrow(AppGlyphs.arrowDown),
                TextSpan(
                  text: ' ${(trackerInfo.downloadSpeed ?? 0).traffic.show}/s',
                ),
              ],
            ),
          ),
          ?action,
        ],
      ),
      children: [
        Text(trackerInfo.start.getLastUpdateTimeDesc(context, compact: true)),
        network,
      ],
    );
  }
}

class _TrackerInfoBody extends StatelessWidget {
  final TrackerInfo trackerInfo;
  final bool showIcon;
  final Function(String)? onClickKeyword;

  const _TrackerInfoBody({
    required this.trackerInfo,
    required this.showIcon,
    this.onClickKeyword,
  });

  Widget _buildTitle(RecordTextStyles styles) {
    final metadata = trackerInfo.metadata;
    final title = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: _endpointText(trackerInfo.title, metadata.destinationPort),
            style: styles.title,
          ),
          if (metadata.host.isNotEmpty && metadata.destinationIP.isNotEmpty)
            TextSpan(
              text: '  ${metadata.destinationIP}',
              style: styles.secondary,
            ),
        ],
      ),
    );
    final process = metadata.process;
    if (!showIcon || process.isEmpty) {
      return title;
    }
    return Row(
      spacing: 8,
      children: [
        GestureDetector(
          onTap: () => onClickKeyword?.call(process),
          child: PackageIcon(packageName: process, size: 24),
        ),
        Flexible(child: title),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final styles = RecordTextStyles.of(context);
    final metadata = trackerInfo.metadata;
    final rule = _ruleText(trackerInfo);
    final source = [
      trackerInfo.progressText,
      _endpointText(metadata.sourceIP, metadata.sourcePort),
    ].where((text) => text.isNotEmpty).join('  ·  ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        _buildTitle(styles),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (rule.isNotEmpty) Text(rule, style: styles.secondary),
            for (final (index, chain) in trackerInfo.chains.reversed.indexed)
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  if (index > 0 || rule.isNotEmpty) const RecordArrow(),
                  Flexible(
                    child: TonalChip(
                      label: chain,
                      color: context.raisedSurfaceLevel.colorOf(colorScheme),
                      foregroundColor: colorScheme.onSurfaceVariant,
                      onPressed: () => onClickKeyword?.call(chain),
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (source.isNotEmpty) Text(source, style: styles.secondary),
      ],
    );
  }
}

class TrackerInfoDetailView extends StatelessWidget {
  final TrackerInfo trackerInfo;

  const TrackerInfoDetailView({super.key, required this.trackerInfo});

  List<Widget> _buildRows(List<(String, String)> entries) {
    return [
      for (final (title, value) in entries)
        if (value.isNotEmpty) DetailRow.text(title: title, value: value),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final metadata = trackerInfo.metadata;
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ).copyWith(bottom: 20, top: context.contentTopPadding),
      children: [
        generateSection(
          title: appLocalizations.basicInfo,
          items: _buildRows([
            (appLocalizations.creationTime, trackerInfo.start.showFull),
            (appLocalizations.networkType, metadata.network),
            (appLocalizations.process, trackerInfo.progressText),
            (appLocalizations.rule, _ruleText(trackerInfo)),
            (appLocalizations.upload, trackerInfo.upload.traffic.show),
            (appLocalizations.download, trackerInfo.download.traffic.show),
            if (trackerInfo.uploadSpeed != null)
              (
                appLocalizations.uploadSpeed,
                '${trackerInfo.uploadSpeed!.traffic.show}/s',
              ),
            if (trackerInfo.downloadSpeed != null)
              (
                appLocalizations.downloadSpeed,
                '${trackerInfo.downloadSpeed!.traffic.show}/s',
              ),
          ]),
        ),
        generateSection(
          title: appLocalizations.address,
          items: _buildRows([
            (appLocalizations.host, metadata.host),
            (
              appLocalizations.source,
              _endpointText(metadata.sourceIP, metadata.sourcePort),
            ),
            (
              appLocalizations.destination,
              _endpointText(metadata.destinationIP, metadata.destinationPort),
            ),
            (
              appLocalizations.destinationGeoIP,
              metadata.destinationGeoIP.join(' '),
            ),
            (appLocalizations.destinationIPASN, metadata.destinationIPASN),
            (appLocalizations.remoteDestination, metadata.remoteDestination),
          ]),
        ),
        generateSection(
          title: appLocalizations.proxies,
          items: [
            ..._buildRows([
              (appLocalizations.specialProxy, metadata.specialProxy),
              (appLocalizations.specialRules, metadata.specialRules),
              (appLocalizations.dnsMode, metadata.dnsMode?.name ?? ''),
            ]),
            ProxyChainsRow(chains: trackerInfo.chains.reversed),
          ],
        ),
      ],
    );
  }
}
