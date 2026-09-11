import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:yaml/yaml.dart';

import '../helpers/test_profiles.dart';

class _MockCore extends Mock implements CoreHandlerInterface {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late _MockCore core;
  late ProviderContainer container;
  late List<String> appliedConfigs;
  final supportDirectory = AppPath.supportDirectory;
  final temporaryDirectory = AppPath.temporaryDirectory;
  final cacheDirectory = AppPath.cacheDirectory;

  ProviderContainer createContainer([PatchClashConfig? config]) {
    final result = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        profilesProvider.overrideWith(TestProfiles.new),
        currentProfileIdProvider.overrideWithBuild((_, _) => null),
        patchClashConfigProvider.overrideWithBuild(
          (_, _) => config ?? const PatchClashConfig(),
        ),
      ],
    );
    globalState.container = result;
    globalState.needInitStatus = true;
    globalState.lastConfigMd5 = null;
    result.listen(patchClashConfigProvider, (_, _) {});
    result.listen(currentProfileIdProvider, (_, _) {});
    result.listen(profilesProvider, (_, _) {});
    return result;
  }

  Future<void> apply() async {
    expect(
      await container
          .read(setupActionProvider.notifier)
          .applyProfile(silence: true),
      isTrue,
    );
  }

  setUpAll(() async {
    registerFallbackValue(const SetupParams(selectedMap: {}, testUrl: ''));
    directory = Directory.systemTemp.createTempSync('geo_config_test');
    AppPath.supportDirectory = () async => directory;
    AppPath.temporaryDirectory = () async => directory;
    AppPath.cacheDirectory = () async => directory;
    await AppLocalizations.load(const Locale('en'));
  });

  setUp(() {
    core = _MockCore();
    appliedConfigs = [];
    when(() => core.setupConfig(any())).thenAnswer((_) async {
      appliedConfigs.add(
        await File(await appPath.configFilePath).readAsString(),
      );
      return '';
    });
    when(
      () => core.getProxies(),
    ).thenAnswer((_) async => const ProxiesData(proxies: {}, all: []));
    when(() => core.getExternalProviders()).thenAnswer((_) async => []);
    when(() => core.updateGeoData(any())).thenAnswer((_) async => '');
    container = createContainer();
  });

  tearDown(() {
    container.dispose();
    globalState.lastConfigMd5 = null;
    globalState.needInitStatus = true;
  });

  tearDownAll(() async {
    AppPath.supportDirectory = supportDirectory;
    AppPath.temporaryDirectory = temporaryDirectory;
    AppPath.cacheDirectory = cacheDirectory;
    await directory.delete(recursive: true);
  });

  test(
    'first launch applies Geo defaults without creating a profile',
    () async {
      await container.read(setupActionProvider.notifier).initStatus();

      final config = loadYaml(appliedConfigs.single) as YamlMap;
      expect(config['geox-url'], defaultGeoXUrl.raw);
      expect(config['geo-auto-update'], isFalse);
      expect(config['geo-update-interval'], 24);
      expect(globalState.lastConfigMd5, appliedConfigs.single.toMd5());
      expect(container.read(profilesProvider), isEmpty);
      expect(container.read(currentProfileIdProvider), isNull);
      verifyNever(() => core.getConfig(any()));
    },
  );

  test(
    'the base configuration matches the real Core download fixture',
    () async {
      final fixture = loadYaml(
        File('test/fixtures/geo_base_config.yaml').readAsStringSync(),
      );
      final config = PatchClashConfig.fromJson(
        jsonDecode(jsonEncode(fixture)) as Map<String, dynamic>,
      );
      container.read(patchClashConfigProvider.notifier).value = config;

      await apply();

      expect(loadYaml(appliedConfigs.single), fixture);
      expect(globalState.lastConfigMd5, appliedConfigs.single.toMd5());
    },
  );

  test(
    'every Geo URL change reloads the base config with a new digest',
    () async {
      globalState.lastConfigMd5 = '';
      await apply();
      final action = container.read(geoResourceActionProvider.notifier);
      final expectedUrls = Map.of(defaultGeoXUrl);

      for (final resource in GeoResource.values) {
        final previousDigest = globalState.lastConfigMd5;
        final url = 'http://geo.test/custom/${resource.configKey}';
        expectedUrls[resource] = url;
        await action.updateGeoResourceUrl(resource, url);

        expect(
          (loadYaml(appliedConfigs.last) as YamlMap)['geox-url'],
          expectedUrls.raw,
        );
        expect(globalState.lastConfigMd5, isNot(previousDigest));
        expect(globalState.lastConfigMd5, appliedConfigs.last.toMd5());
      }

      await apply();
      expect(appliedConfigs, hasLength(1 + GeoResource.values.length));
      expect(container.read(profilesProvider), isEmpty);
    },
  );

  test(
    'automatic update settings also change the base config digest',
    () async {
      await apply();
      final originalDigest = globalState.lastConfigMd5;
      container
          .read(patchClashConfigProvider.notifier)
          .update(
            (state) =>
                state.copyWith(geoAutoUpdate: true, geoUpdateInterval: 12),
          );

      await apply();

      final config = loadYaml(appliedConfigs.last) as YamlMap;
      expect(config['geo-auto-update'], isTrue);
      expect(config['geo-update-interval'], 12);
      expect(globalState.lastConfigMd5, isNot(originalDigest));
    },
  );

  test('partial saved URLs retain all four resource addresses', () async {
    container
        .read(patchClashConfigProvider.notifier)
        .value = const PatchClashConfig(
      geoXUrl: {GeoResource.GEOSITE: 'http://geo.test/custom/geosite.dat'},
    );

    await apply();

    expect((loadYaml(appliedConfigs.single) as YamlMap)['geox-url'], {
      ...defaultGeoXUrl.raw,
      'geosite': 'http://geo.test/custom/geosite.dat',
    });
  });

  test(
    'a queued manual update uses the last of consecutive URL edits',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      when(() => core.setupConfig(any())).thenAnswer((_) async {
        appliedConfigs.add(
          await File(await appPath.configFilePath).readAsString(),
        );
        if (appliedConfigs.length == 1) {
          started.complete();
          await release.future;
        }
        return '';
      });
      String? urlAtDownload;
      when(() => core.updateGeoData('GEOSITE')).thenAnswer((_) async {
        urlAtDownload =
            (loadYaml(appliedConfigs.last) as YamlMap)['geox-url']['geosite']
                as String;
        return '';
      });
      final action = container.read(geoResourceActionProvider.notifier);
      final first = action.updateGeoResourceUrl(
        GeoResource.GEOSITE,
        'http://geo.test/first/geosite.dat',
      );
      await started.future.timeout(const Duration(seconds: 5));
      final second = action.updateGeoResourceUrl(
        GeoResource.GEOSITE,
        'http://geo.test/second/geosite.dat',
      );
      final update = action.updateGeoResource(GeoResource.GEOSITE);

      verifyNever(() => core.updateGeoData(any()));
      release.complete();
      await Future.wait([first, second, update]);

      expect(urlAtDownload, 'http://geo.test/second/geosite.dat');
      expect(appliedConfigs, hasLength(2));
    },
  );

  test(
    'a rejected setup blocks downloading and allows a later retry',
    () async {
      when(() => core.setupConfig(any())).thenAnswer((_) async => 'rejected');
      final action = container.read(geoResourceActionProvider.notifier);

      await expectLater(
        action.updateGeoResource(GeoResource.GEOSITE),
        throwsA(isA<MessageException>()),
      );

      verifyNever(() => core.updateGeoData(any()));
      expect(globalState.lastConfigMd5, isNull);
      expect(
        container.read(isUpdatingProvider(GeoResource.GEOSITE.updatingKey)),
        isFalse,
      );

      when(() => core.setupConfig(any())).thenAnswer((_) async => '');
      await action.updateGeoResource(GeoResource.GEOSITE);
      verify(() => core.updateGeoData('GEOSITE')).called(1);
    },
  );

  test('a failed URL sync keeps the new address for retry', () async {
    when(() => core.setupConfig(any())).thenAnswer((_) async => 'rejected');

    await expectLater(
      container
          .read(geoResourceActionProvider.notifier)
          .updateGeoResourceUrl(
            GeoResource.GEOSITE,
            'http://geo.test/retry/geosite.dat',
          ),
      throwsA(isA<MessageException>()),
    );

    expect(
      container.read(patchClashConfigProvider).geoXUrl[GeoResource.GEOSITE],
      'http://geo.test/retry/geosite.dat',
    );
    verifyNever(() => core.updateGeoData(any()));
  });

  test('Core restart reapplies unchanged Geo settings', () async {
    await apply();
    when(() => core.restart()).thenAnswer(
      (_) async => const CoreLifecycleResult(
        revision: 1,
        outcome: CoreLifecycleOutcome.applied,
      ),
    );
    when(() => core.isInit).thenAnswer((_) async => true);

    expect(
      await container.read(coreActionProvider.notifier).restartCore(),
      isTrue,
    );

    expect(appliedConfigs, hasLength(2));
    expect(appliedConfigs.last, appliedConfigs.first);
  });

  test(
    'application relaunch restores persisted Geo settings without profiles',
    () async {
      await container
          .read(geoResourceActionProvider.notifier)
          .updateGeoResourceUrl(
            GeoResource.GEOSITE,
            'http://geo.test/relaunch/geosite.dat',
          );
      final saved = jsonEncode(container.read(patchClashConfigProvider));
      container.dispose();
      container = createContainer(PatchClashConfig.fromJson(jsonDecode(saved)));

      await container.read(setupActionProvider.notifier).initStatus();

      expect(appliedConfigs, hasLength(2));
      expect(appliedConfigs.last, appliedConfigs.first);
      expect(container.read(profilesProvider), isEmpty);
    },
  );

  test(
    'deleting the last profile preserves Geo settings on the next sync',
    () async {
      final profile = Profile.normal(label: 'last profile');
      container.read(profilesProvider.notifier).put(profile);
      container.read(currentProfileIdProvider.notifier).value = profile.id;
      container
          .read(patchClashConfigProvider.notifier)
          .update(
            (state) => state.copyWith(
              geoXUrl: {
                ...state.geoXUrl,
                GeoResource.GEOSITE: 'http://geo.test/kept.dat',
              },
              geoAutoUpdate: true,
              geoUpdateInterval: 12,
            ),
          );
      when(() => core.clearEffect(profile.id)).thenAnswer((_) async => '');
      when(() => core.stopListener()).thenAnswer((_) async => true);

      await container
          .read(profilesActionProvider.notifier)
          .deleteProfile(profile.id);
      await container
          .read(geoResourceActionProvider.notifier)
          .updateGeoResource(GeoResource.GEOSITE);

      final config = loadYaml(appliedConfigs.single) as YamlMap;
      expect(config['geox-url']['geosite'], 'http://geo.test/kept.dat');
      expect(config['geo-auto-update'], isTrue);
      expect(config['geo-update-interval'], 12);
      expect(config.containsKey('proxies'), isFalse);
      expect(container.read(profilesProvider), isEmpty);
      expect(container.read(currentProfileIdProvider), isNull);
      verify(() => core.updateGeoData('GEOSITE')).called(1);
      verifyNever(() => core.getConfig(any()));
    },
  );
}
