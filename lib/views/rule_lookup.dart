import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/core/rule_lookup.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class RuleLookupView extends ConsumerStatefulWidget {
  const RuleLookupView({super.key});

  @override
  ConsumerState<RuleLookupView> createState() => _RuleLookupViewState();
}

class _RuleLookupViewState extends ConsumerState<RuleLookupView> {
  final _formKey = GlobalKey<FormState>();
  final _targetController = TextEditingController();
  final _sourcePortController = TextEditingController();
  final _destinationPortController = TextEditingController(text: '443');
  String _network = 'tcp';
  bool _loading = false;
  RuleLookupResult? _result;
  String? _error;

  @override
  void dispose() {
    _targetController.dispose();
    _sourcePortController.dispose();
    _destinationPortController.dispose();
    super.dispose();
  }

  void _clearResult() {
    setState(() {
      _result = null;
      _error = null;
    });
  }

  Future<void> _lookup() async {
    if (_loading || ref.read(coreStatusProvider) != CoreStatus.connected) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
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
            target: _targetController.text.trim(),
            sourcePort: int.tryParse(_sourcePortController.text) ?? 0,
            destinationPort: int.parse(_destinationPortController.text),
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

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.textTheme.labelLarge),
          const SizedBox(height: 4),
          SelectableText(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final connected = ref.watch(coreStatusProvider) == CoreStatus.connected;
    final result = _result;
    return CommonScaffold(
      title: l.ruleLookup,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
          top: context.contentTopPadding + 16,
          bottom: 20 + BottomInsetScope.of(context),
        ),
        children: [
          Text(l.ruleLookupDesc),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _targetController,
                  enabled: !_loading,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: l.ruleLookupTarget),
                  onChanged: (_) => _clearResult(),
                  validator: (value) {
                    final target = value?.trim() ?? '';
                    if (target.isEmpty ||
                        (InternetAddress.tryParse(target) == null &&
                            RegExp(r'[\s/:?#@\[\]\\]').hasMatch(target))) {
                      return l.ruleLookupInvalidTarget;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _sourcePortController,
                  enabled: !_loading,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l.sourcePort,
                    helperText: l.ruleLookupSourcePortHint,
                  ),
                  onChanged: (_) => _clearResult(),
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    final port = int.tryParse(value);
                    return port == null || port < 1 || port > 65535
                        ? l.ruleLookupInvalidPort
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _destinationPortController,
                  enabled: !_loading,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(labelText: l.destinationPort),
                  onChanged: (_) => _clearResult(),
                  onFieldSubmitted: (_) => _lookup(),
                  validator: (value) {
                    final port = int.tryParse(value ?? '');
                    return port == null || port < 1 || port > 65535
                        ? l.ruleLookupInvalidPort
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                AbsorbPointer(
                  absorbing: _loading,
                  child: ListItem<String>.options(
                    padding: EdgeInsets.zero,
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
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: connected && !_loading ? _lookup : null,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l.ruleLookupQuery),
                ),
              ],
            ),
          ),
          if (!connected) ...[
            const SizedBox(height: 16),
            Text(l.ruleLookupCoreRequired),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: context.colorScheme.error)),
          ],
          if (result != null) ...[
            const SizedBox(height: 24),
            _resultRow(l.ruleLookupTarget, result.target),
            if (result.sourcePort != 0)
              _resultRow(l.sourcePort, '${result.sourcePort}'),
            _resultRow(l.destinationPort, '${result.destinationPort}'),
            _resultRow(l.networkType, result.network.toUpperCase()),
            _resultRow(l.mode, Mode.values.byName(result.mode).label),
            _resultRow(l.ruleTarget, result.proxy),
            _resultRow(
              l.rule,
              result.rule.isEmpty ? l.ruleLookupNoRule : result.rule,
            ),
            if (result.rulePayload.isNotEmpty)
              _resultRow(l.ruleLookupPayload, result.rulePayload),
            _resultRow(l.proxyChains, result.chains.join(' → ')),
            if (result.destinationIp.isNotEmpty)
              _resultRow(l.destination, result.destinationIp),
          ],
          const SizedBox(height: 16),
          Text(l.ruleLookupNote, style: context.textTheme.bodySmall),
        ],
      ),
    );
  }
}
