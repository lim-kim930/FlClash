import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/ip_quality.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/ip_quality.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';

import 'ip_quality_text.dart';
import 'labels.dart';

Future<void> showIpQualitySheet(BuildContext context, {required String ip}) {
  return showNestedSheet<void>(
    context,
    builder: (_) => _IpQualitySheet(ip: ip),
  );
}

class _IpQualitySheet extends ConsumerWidget {
  const _IpQualitySheet({required this.ip});

  final String ip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = context.appLocalizations;
    final source = ref.watch(
      appSettingProvider.select((state) => state.ipQualitySource),
    );
    final provider = ipQualityProvider(ip, source: source);
    final isLoading = ref.watch(provider.select((result) => result.isLoading));
    return Scaffold(
      title: localizations.outboundIp,
      actions: [
        AppBarActionButton(
          data: IconButtonData(
            glyph: AppGlyphs.refresh,
            tooltip: localizations.ipQualityRetry,
            isLoading: isLoading,
            onPressed: () => ref.invalidate(provider),
          ),
        ),
      ],
      body: ListTextScope(
        scale: ListTextScale.compact,
        child: _IpQualityDetail(ip: ip),
      ),
    );
  }
}

class _HideIpItem extends ConsumerWidget {
  const _HideIpItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideIp = ref.watch(
      appSettingProvider.select((state) => state.hideIp),
    );
    void update(bool value) => ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(hideIp: value));
    return DecorationListItem(
      title: Text(context.appLocalizations.hideIp),
      onPressed: () => update(!hideIp),
      trailing: Switch(value: hideIp, onChanged: update),
    );
  }
}

class _IpQualityDetail extends ConsumerWidget {
  const _IpQualityDetail({required this.ip});

  final String ip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = context.appLocalizations;
    final source = ref.watch(
      appSettingProvider.select((state) => state.ipQualitySource),
    );
    final result = ref.watch(ipQualityProvider(ip, source: source));
    final quality = result.value;
    final error = result.error;
    final failed = quality == null && !result.isLoading;
    return ListView(
      shrinkWrap: true,
      padding: context.listInsets.page().copyWith(
        bottom: 20 + context.bottomInset,
        top: context.contentTopPadding,
      ),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.listInsets.leading,
          ).copyWith(top: infoSectionContentGap),
          child: Text(
            localizations.detectionTip,
            style: context.listCaptionStyle,
          ),
        ),
        generateSection(
          title: localizations.basicInfo,
          items: [
            DetailRow(
              title: localizations.ipAddress,
              copyText: ip,
              value: IpQualityText(ip: ip),
            ),
            if (failed)
              DetailRow(
                title: localizations.ipType,
                value: Text(
                  localizations.ipQualityFailed,
                  style: TextStyle(color: context.colorScheme.error),
                ),
              )
            else
              ..._qualityRows(context, quality),
          ],
        ),
        if (!failed)
          generateSection(
            title: localizations.network,
            items: _networkRows(context, quality),
          ),
        if (failed && error is IpQualityLookupException)
          generateSection(
            title: localizations.ipQualitySources,
            items: [
              for (final failure in error.failures)
                DetailRow(
                  title: failure.source.label,
                  value: Text(failure.status.label(context)),
                ),
            ],
          ),
        generateSection(
          title: localizations.other,
          items: [
            ConfigOptionsItem<IpInfoSource?>(
              selector: appSettingProvider.select(
                (state) => state.ipInfoSource,
              ),
              title: (l10n) => l10n.ipInfoLookupSource,
              options: const [null, ...IpInfoSource.values],
              textBuilder: (source) =>
                  source?.label ?? localizations.ipLookupAuto,
              onChanged: (ref, source) => ref
                  .read(appSettingProvider.notifier)
                  .update((state) => state.copyWith(ipInfoSource: source)),
            ),
            ConfigOptionsItem<IpQualitySource?>(
              selector: appSettingProvider.select(
                (state) => state.ipQualitySource,
              ),
              title: (l10n) => l10n.ipQualityLookupSource,
              options: const [null, ...IpQualitySource.values],
              textBuilder: (source) =>
                  source?.label ?? localizations.ipLookupAuto,
              onChanged: (ref, source) => ref
                  .read(appSettingProvider.notifier)
                  .update((state) => state.copyWith(ipQualitySource: source)),
            ),
            const _HideIpItem(),
          ],
        ),
      ],
    );
  }

  /// A lookup still running lays out every row it will fill, so the page
  /// keeps its height when the values arrive.
  List<Widget> _qualityRows(BuildContext context, IpQuality? quality) {
    final localizations = context.appLocalizations;
    if (quality == null) {
      return [
        DetailRow(
          title: localizations.ipQualityLevel,
          value: const SkeletonText(width: 40),
        ),
        DetailRow(
          title: localizations.ipType,
          value: const SkeletonText(width: 64),
        ),
        DetailRow(
          title: localizations.ipFlags,
          value: const SkeletonText(width: 40),
        ),
      ];
    }
    final flags = [
      if (quality.isTor) localizations.ipFlagTor,
      if (quality.isAbuser) localizations.ipFlagAbuser,
      if (quality.isVpn) localizations.ipFlagVpn,
      if (quality.isProxy) localizations.ipFlagProxy,
    ];
    return [
      DetailRow(
        title: localizations.ipQualityLevel,
        value: Text(
          quality.level.label(context),
          style: TextStyle(color: quality.level.color(context)),
        ),
      ),
      DetailRow(
        title: localizations.ipType,
        value: Text(quality.type.label(context)),
      ),
      DetailRow(
        title: localizations.ipFlags,
        value: flags.isEmpty
            ? Text(localizations.none)
            : Wrap(
                spacing: 6,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: [for (final flag in flags) MetaChip(label: flag)],
              ),
      ),
    ];
  }

  List<Widget> _networkRows(BuildContext context, IpQuality? quality) {
    final localizations = context.appLocalizations;
    Widget valueOf(String? text, {required double width}) =>
        switch ((quality, text)) {
          (null, _) => SkeletonText(width: width),
          (_, final text?) => Text(text),
          _ => const Text('—'),
        };
    final organization = quality?.organization;
    final asn = switch (quality?.asn) {
      final asn? => 'AS$asn',
      null => null,
    };
    return [
      DetailRow(
        title: localizations.ipOrganization,
        copyText: organization,
        value: valueOf(organization, width: 120),
      ),
      DetailRow(
        title: localizations.ipAsn,
        copyText: asn,
        value: valueOf(asn, width: 56),
      ),
      DetailRow(
        title: localizations.ipQualitySource,
        value: valueOf(quality?.source.label, width: 72),
      ),
    ];
  }
}
