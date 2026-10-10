import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/core/rule_lookup.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

const _maxContentWidth = 680.0;

class RuleLookupView extends ConsumerStatefulWidget {
  const RuleLookupView({super.key});

  @override
  ConsumerState<RuleLookupView> createState() => _RuleLookupViewState();
}

class _RuleLookupViewState extends ConsumerState<RuleLookupView> {
  String _target = '';
  String _sourcePort = '';
  String _destinationPort = '443';
  String _network = 'tcp';
  bool _loading = false;
  RuleLookupResult? _result;
  String? _error;

  void _clearResult() {
    setState(() {
      _result = null;
      _error = null;
    });
  }

  String? _validateTarget(String? value) {
    final target = value?.trim() ?? '';
    if (target.isEmpty ||
        (InternetAddress.tryParse(target) == null &&
            RegExp(r'[\s/:?#@\[\]\\]').hasMatch(target))) {
      return context.appLocalizations.ruleLookupInvalidTarget;
    }
    return null;
  }

  String? _validatePort(String? value, {bool optional = false}) {
    if (optional && (value == null || value.isEmpty)) return null;
    final port = int.tryParse(value ?? '');
    return port == null ||
            !RegExp(r'^\d+$').hasMatch(value ?? '') ||
            port < 1 ||
            port > 65535
        ? context.appLocalizations.ruleLookupInvalidPort
        : null;
  }

  Future<void> _lookup() async {
    if (_loading || ref.read(coreStatusProvider) != CoreStatus.connected) {
      return;
    }
    final validationError =
        _validateTarget(_target) ??
        _validatePort(_sourcePort, optional: true) ??
        _validatePort(_destinationPort);
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    FocusScope.of(context).unfocus();
    final l = context.appLocalizations;
    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });
    try {
      final result = await ref
          .read(coreHandlerProvider)
          .ruleLookup(
            target: _target,
            sourcePort: int.tryParse(_sourcePort) ?? 0,
            destinationPort: int.parse(_destinationPort),
            network: _network,
          );
      if (mounted) {
        setState(() => _result = result);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error =
              error is CoreMethodException && error.code == 'invalid_arguments'
              ? l.ruleLookupInvalidTarget
              : l.ruleLookupFailed;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildStatusMessage({
    required String message,
    required Glyph glyph,
    required Color containerColor,
    required Color contentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: ShapeDecoration(color: containerColor, shape: AppShape.md),
      child: Row(
        children: [
          GlyphIcon(glyph, color: contentColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: context.textTheme.bodyMedium?.copyWith(
                color: contentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(AppLocalizations l, bool connected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AbsorbPointer(
          absorbing: _loading,
          child: Column(
            children: [
              generateSectionV3(
                title: l.source,
                items: [
                  ListItem.input(
                    title: Text(l.sourcePort),
                    subtitle: Text(
                      _sourcePort.isEmpty
                          ? l.ruleLookupSourcePortHint
                          : _sourcePort,
                    ),
                    dialogTitle: l.sourcePort,
                    value: _sourcePort,
                    maxLength: TextInputLimits.port,
                    keyboardType: TextInputType.number,
                    validator: (value) => _validatePort(value, optional: true),
                    onChanged: (value) {
                      if (!mounted || _loading || value == null) return;
                      _sourcePort = value;
                      _clearResult();
                    },
                  ),
                ],
              ),
              generateSectionV3(
                title: l.ruleLookupDestination,
                items: [
                  ListItem.input(
                    title: Text(l.ruleLookupTarget),
                    subtitle: _target.isEmpty ? null : Text(_target),
                    dialogTitle: l.ruleLookupTarget,
                    value: _target,
                    maxLength: TextInputLimits.domain,
                    keyboardType: TextInputType.url,
                    validator: _validateTarget,
                    onChanged: (value) {
                      if (!mounted || _loading || value == null) return;
                      _target = value.trim();
                      _clearResult();
                    },
                  ),
                  ListItem.input(
                    title: Text(l.destinationPort),
                    subtitle: Text(_destinationPort),
                    dialogTitle: l.destinationPort,
                    value: _destinationPort,
                    maxLength: TextInputLimits.port,
                    keyboardType: TextInputType.number,
                    validator: _validatePort,
                    onChanged: (value) {
                      if (!mounted || _loading || value == null) return;
                      _destinationPort = value;
                      _clearResult();
                    },
                  ),
                ],
              ),
              generateSectionV3(
                title: l.other,
                items: [
                  ListItem<String>.options(
                    title: Text(l.networkType),
                    subtitle: Text(_network.toUpperCase()),
                    dialogTitle: l.networkType,
                    options: const ['tcp', 'udp'],
                    value: _network,
                    textBuilder: (value) => value.toUpperCase(),
                    onChanged: (value) {
                      if (!mounted || _loading || value == null) return;
                      _network = value;
                      _clearResult();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ElasticButton(
          child: FilledButton(
            onPressed: connected && !_loading ? _lookup : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: AppShape.xl,
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const GlyphIcon(AppGlyphs.search, size: 18, fill: 1),
                      const SizedBox(width: 8),
                      Text(l.ruleLookupQuery),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildResults(AppLocalizations l, RuleLookupResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        generateSectionV3(
          title: l.rules,
          items: [
            DetailRow(
              title: l.ruleTarget,
              value: Text(
                result.proxy,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              copyText: result.proxy,
            ),
            DetailRow.text(
              title: l.rule,
              value: result.rule.isEmpty ? l.ruleLookupNoRule : result.rule,
            ),
            if (result.rulePayload.isNotEmpty)
              DetailRow.text(
                title: l.ruleLookupPayload,
                value: result.rulePayload,
              ),
            DetailRow.text(
              title: l.proxyChains,
              value: result.chains.join(' → '),
            ),
            DetailRow.text(
              title: l.mode,
              value: Mode.values.byName(result.mode).label,
            ),
          ],
        ),
        const SizedBox(height: 16),
        generateSectionV3(
          title: l.basicInfo,
          items: [
            DetailRow.text(title: l.ruleLookupTarget, value: result.target),
            if (result.destinationIp.isNotEmpty)
              DetailRow.text(title: l.destination, value: result.destinationIp),
            DetailRow.text(
              title: l.destinationPort,
              value: '${result.destinationPort}',
            ),
            if (result.sourcePort != 0)
              DetailRow.text(
                title: l.sourcePort,
                value: '${result.sourcePort}',
              ),
            DetailRow.text(
              title: l.networkType,
              value: result.network.toUpperCase(),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final connected = ref.watch(coreStatusProvider) == CoreStatus.connected;
    final result = _result;
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: l.ruleLookup,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
          top: context.contentTopPadding + 16,
          bottom: 20 + BottomInsetScope.of(context),
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListHeader(
                    title: l.ruleLookup,
                    subTitle: l.ruleLookupDesc,
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                  ),
                  _buildForm(l, connected),
                  if (!connected) ...[
                    const SizedBox(height: 16),
                    _buildStatusMessage(
                      message: l.ruleLookupCoreRequired,
                      glyph: AppGlyphs.info,
                      containerColor: colorScheme.errorContainer.opacity80,
                      contentColor: colorScheme.onErrorContainer,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _buildStatusMessage(
                      message: _error!,
                      glyph: AppGlyphs.close,
                      containerColor: colorScheme.errorContainer.opacity80,
                      contentColor: colorScheme.onErrorContainer,
                    ),
                  ],
                  if (result != null) ...[
                    const SizedBox(height: 24),
                    _buildResults(l, result),
                  ],
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: GlyphIcon(
                            AppGlyphs.info,
                            size: 14,
                            color: colorScheme.outline,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l.ruleLookupNote,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
