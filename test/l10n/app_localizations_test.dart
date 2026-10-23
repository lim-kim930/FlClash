import 'package:fl_clash/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('load resolves accessors for every supported locale', () async {
    for (final locale in AppLocalizations.delegate.supportedLocales) {
      final appLocalizations = await AppLocalizations.load(locale);

      expect(AppLocalizations.current, same(appLocalizations));
      expect(appLocalizations.dashboard, isNotEmpty);
      expect(appLocalizations.sortAsc, isNotEmpty);
      expect(appLocalizations.sortDesc, isNotEmpty);
      expect(appLocalizations.downloadSpeed, isNotEmpty);
      expect(appLocalizations.uploadSpeed, isNotEmpty);
      expect(appLocalizations.clearRequests, isNotEmpty);
      expect(appLocalizations.clearDnsQueries, isNotEmpty);
      expect(appLocalizations.geoConfigSyncFailed, isNotEmpty);
      expect(appLocalizations.ruleLookup, isNotEmpty);
      expect(appLocalizations.ruleLookupNote, isNotEmpty);
      expect(appLocalizations.proxies, isNotEmpty);
      expect(appLocalizations.settings, isNotEmpty);
      expect(appLocalizations.secondsCount(30), contains('30'));
      expect(appLocalizations.geoUpdated('geoip'), contains('geoip'));
    }
  });

  test('delegate recognizes only supported locales', () {
    expect(AppLocalizations.delegate.isSupported(const Locale('en')), isTrue);
    expect(AppLocalizations.delegate.isSupported(const Locale('de')), isFalse);
    expect(
      AppLocalizations.delegate.shouldReload(AppLocalizations.delegate),
      isFalse,
    );
  });
}
