part of '../action.dart';

enum _SetupTaskResult { completed, handoffToCoreRestart }

class _RunRequest {
  final bool running;
  final bool initialize;

  const _RunRequest({required this.running, required this.initialize});
}

@Riverpod(keepAlive: true)
class SetupAction extends _$SetupAction {
  Timer? _runtimeTimer;
  final _setupScheduler = SerialTaskScheduler();
  final _listenerScheduler = SerialTaskScheduler();
  _RunRequest? _latestRunRequest;
  DateTime? _startTime;

  bool get _isRunning => _startTime != null && _startTime!.isBeforeNow;

  @override
  void build() {}

  SetupParams get _setupParams {
    final selectedMap = ref.read(selectedMapProvider);
    final testUrl = ref.read(
      appSettingProvider.select((state) => state.testUrl),
    );
    return SetupParams(selectedMap: selectedMap, testUrl: testUrl);
  }

  void fullSetup() {
    if (!ref.read(initProvider)) return;
    ref.read(delayDataSourceProvider.notifier).value = {};
    unawaited(_runSetup(force: true));
    ref.read(logsProvider.notifier).value = FixedList(500);
    ref.read(requestsProvider.notifier).value = FixedList(500);
  }

  void _setLocalRunning(bool running) {
    _runtimeTimer?.cancel();
    _runtimeTimer = null;
    if (!running) {
      _startTime = null;
      debouncer.cancel(FunctionTag.applyProfile);
      _updateRunTime();
      return;
    }

    _startTime ??= DateTime.now();
    _refreshRunningState();
    _runtimeTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshRunningState(),
    );
  }

  void _refreshRunningState() {
    _updateRunTime();
    unawaited(ref.read(commonActionProvider.notifier).updateTraffic());
  }

  void _updateRunTime() {
    final startTime = _startTime;
    ref.read(runTimeProvider.notifier).value = startTime == null
        ? null
        : DateTime.now().millisecondsSinceEpoch -
              startTime.millisecondsSinceEpoch;
  }

  Future<void> _updateStartTime() async {
    _startTime = await service?.getRunTime();
  }

  Future<void> initStatus() async {
    if (!globalState.needInitStatus) {
      commonPrint.log('init status cancel');
      return;
    }
    commonPrint.log('init status');
    if (system.isAndroid) {
      await _updateStartTime();
    }
    final shouldRun = _isRunning || ref.read(appSettingProvider).autoRun;
    if (shouldRun) {
      await setRunning(true, initialize: true);
    } else {
      await applyProfile(force: true);
    }
  }

  Future<void> setRunning(bool running, {bool initialize = false}) {
    if (running && !initialize && !ref.read(initProvider)) {
      return Future.value();
    }

    final request = _RunRequest(
      running: running,
      initialize: running && initialize,
    );
    _latestRunRequest = request;
    _setLocalRunning(running);
    if (request.initialize) {
      globalState.needInitStatus = false;
    }
    return running ? _start(request) : _stop(request);
  }

  Future<void> _start(_RunRequest request) async {
    if (request.initialize) {
      try {
        await applyProfile(
          force: true,
          preloadInvoke: () => _setCoreRunning(request),
        );
      } catch (_) {
        if (_isCurrent(request)) {
          await setRunning(false);
        }
      }
      return;
    }

    await _setCoreRunning(request);
    if (_isCurrent(request)) {
      applyProfileDebounce(force: true, silence: true);
    }
  }

  Future<void> _stop(_RunRequest request) async {
    await _setCoreRunning(request);
    if (!_isCurrent(request)) {
      return;
    }
    resetCoreTraffic();
    ref.read(trafficsProvider.notifier).clear();
    ref.read(totalTrafficProvider.notifier).value = const Traffic();
    ref.read(checkIpNumProvider.notifier).add();
  }

  Future<void> _setCoreRunning(_RunRequest request) {
    return _listenerScheduler.run(() async {
      if (!_isCurrent(request)) {
        return;
      }
      if (request.running && ref.read(suspendProvider)) {
        return;
      }
      await setCoreRunning(request.running);
    });
  }

  bool _isCurrent(_RunRequest request) => identical(_latestRunRequest, request);

  Future<void> updateConfigDebounce() async {
    debouncer.call(FunctionTag.updateConfig, updateConfig);
  }

  @protected
  Future<bool> setCoreRunning(bool running) {
    return running
        ? coreController.startListener()
        : coreController.stopListener();
  }

  @protected
  void resetCoreTraffic() {
    coreController.resetTraffic();
  }

  @visibleForTesting
  Future<void> updateConfig() async {
    await globalState.safeRun(() async {
      final updateParams = ref.read(updateParamsProvider);
      final shouldContinueSetup = await requestAdmin(updateParams.tun.enable);
      if (!shouldContinueSetup) {
        commonPrint.log(
          'TUN update handed off to Core restart after authorization',
        );
        await _restartCoreAfterAuthorization();
        return;
      }
      final authorizationState = ref.read(authorizedTunEnableProvider);
      final effectiveTunEnable = _getEffectiveTunEnable(
        updateParams.tun.enable,
      );
      commonPrint.log(
        'TUN update decision requested=${updateParams.tun.enable} '
        'authorization=${authorizationState.name} '
        'effective=$effectiveTunEnable',
        logLevel: updateParams.tun.enable && !effectiveTunEnable
            ? LogLevel.warning
            : LogLevel.info,
      );
      final message = await coreController.updateConfig(
        updateParams.copyWith.tun(enable: effectiveTunEnable),
      );
      commonPrint.log(
        'Core TUN update response '
        'effective=$effectiveTunEnable messageEmpty=${message.isEmpty}',
        logLevel: message.isEmpty ? LogLevel.info : LogLevel.warning,
      );
      ref.read(checkIpNumProvider.notifier).add();
      if (message.isNotEmpty) throw message;
    });
  }

  void tryCheckIp() {
    final isTimeout = ref.read(
      networkDetectionProvider.select(
        (state) => state.ipInfo == null && state.isLoading == false,
      ),
    );
    if (!isTimeout) return;
    ref.read(checkIpNumProvider.notifier).add();
  }

  void applyProfileDebounce({bool silence = false, bool force = false}) {
    debouncer.call(FunctionTag.applyProfile, (silence, force) {
      applyProfile(silence: silence, force: force);
    }, args: [silence, force]);
  }

  void changeMode(Mode mode) {
    ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(mode: mode));
    if (mode == Mode.global) {
      ref
          .read(proxiesActionProvider.notifier)
          .updateCurrentGroupName(GroupName.GLOBAL.name);
    }
  }

  void autoApplyProfile() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      applyProfile();
    });
  }

  Future<void> applyProfile({
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) {
    return _runSetup(
      force: force,
      silence: silence,
      preloadInvoke: preloadInvoke,
    );
  }

  Future<void> _runSetup({
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async {
    final result = await _setupScheduler.run(() {
      return _setupConfig(
        force: force,
        silence: silence,
        preloadInvoke: preloadInvoke,
        onUpdated: () async {
          await ref.read(proxiesActionProvider.notifier).updateGroups();
          await ref.read(providersProvider.notifier).syncProviders();
        },
      );
    });
    if (result != _SetupTaskResult.handoffToCoreRestart) {
      return;
    }
    // Release the current serial task before restartCore reapplies the profile.
    await _restartCoreAfterAuthorization();
  }

  Future<void> _restartCoreAfterAuthorization() async {
    try {
      await ref.read(coreActionProvider.notifier).restartCore();
    } catch (_) {
      ref.read(authorizedTunEnableProvider.notifier).value =
          TunAuthorizationState.none;
      rethrow;
    }
  }

  Future<VM2<String, String>> getProfile({
    required SetupState setupState,
    required PatchClashConfig patchConfig,
  }) async {
    final profileId = setupState.profileId;
    if (profileId == null) return const VM2('', '');
    final defaultUA = globalState.packageInfo.ua;
    final networkVM2 = ref.read(
      networkSettingProvider.select(
        (state) => VM2(state.appendSystemDns, state.routeMode),
      ),
    );
    final overrideDns = ref.read(overrideDnsProvider);
    final appendSystemDns = networkVM2.a;
    final routeMode = networkVM2.b;
    final configMap = await coreController.getConfig(profileId);
    String? scriptContent;
    final List<Rule> addedRules = [];
    final List<ProxyGroup> proxyGroups = [];
    final List<Rule> rules = [];
    if (setupState.overwriteType == OverwriteType.script) {
      scriptContent = await setupState.script?.content;
    } else if (setupState.overwriteType == OverwriteType.standard) {
      addedRules.addAll(setupState.addedRules);
    } else {
      proxyGroups.addAll(setupState.proxyGroups);
      rules.addAll(setupState.rules);
    }
    final realPatchConfig = patchConfig.copyWith(
      tun: patchConfig.tun.getRealTun(routeMode),
    );
    Map<String, dynamic> rawConfig = configMap;
    if (scriptContent?.isNotEmpty == true) {
      rawConfig = await handleEvaluate(scriptContent!, rawConfig);
    }
    final directory = await appPath.profilesPath;
    final res = makeRealProfileTask(
      MakeRealProfileState(
        rules: rules,
        proxyGroups: proxyGroups,
        profilesPath: directory,
        profileId: profileId,
        rawConfig: rawConfig,
        realPatchConfig: realPatchConfig,
        overrideDns: overrideDns,
        appendSystemDns: appendSystemDns,
        addedRules: addedRules,
        defaultUA: defaultUA,
      ),
    );
    return res;
  }

  Future<String> getProfileWithId(int profileId) async {
    try {
      final setupState = await ref.read(setupStateProvider(profileId).future);
      final patchClashConfig = ref.read(patchClashConfigProvider);
      final res = await getProfile(
        setupState: setupState,
        patchConfig: patchClashConfig,
      );
      return res.a;
    } catch (e) {
      globalState.showNotifier(e.toString());
    }
    return '';
  }

  bool _getEffectiveTunEnable(bool enableTun) {
    final authorizationState = ref.read(authorizedTunEnableProvider);
    return enableTun && authorizationState == TunAuthorizationState.authorized;
  }

  @protected
  Future<AuthorizeCode> authorizeCore() {
    return system.authorizeCore();
  }

  @protected
  Future<bool> hasCorePrivilege() {
    return system.checkIsAdmin();
  }

  @visibleForTesting
  Future<bool> requestAdmin(bool enableTun) async {
    final currentState = ref.read(authorizedTunEnableProvider);
    commonPrint.log(
      'TUN authorization requested=$enableTun state=${currentState.name}',
    );
    if (!enableTun) {
      commonPrint.log('TUN authorization skipped because TUN is disabled');
      return true;
    }
    final authorizationState = currentState;
    final authorizationNotifier = ref.read(
      authorizedTunEnableProvider.notifier,
    );
    if (authorizationState == TunAuthorizationState.authorized) {
      commonPrint.log('TUN authorization reused authorized state');
      return true;
    }
    if (authorizationState == TunAuthorizationState.unauthorized) {
      final hasPrivilege = await hasCorePrivilege();
      commonPrint.log(
        'TUN authorization silent privilege re-probe '
        'available=$hasPrivilege',
        logLevel: hasPrivilege ? LogLevel.info : LogLevel.warning,
      );
      if (!hasPrivilege) {
        commonPrint.log(
          'TUN remains unauthorized; setup will continue with TUN disabled',
          logLevel: LogLevel.warning,
        );
        return true;
      }
      authorizationNotifier.value = TunAuthorizationState.authorized;
      commonPrint.log(
        'TUN authorization recovered; handing off to Core restart',
      );
      return false;
    }

    authorizationNotifier.value = TunAuthorizationState.unauthorized;
    commonPrint.log('TUN authorization state set to unauthorized before probe');

    final code = await authorizeCore();
    commonPrint.log(
      'TUN authorization platform result=${code.name}',
      logLevel: code == AuthorizeCode.error ? LogLevel.warning : LogLevel.info,
    );

    switch (code) {
      case AuthorizeCode.success:
        authorizationNotifier.value = TunAuthorizationState.authorized;
        commonPrint.log(
          'TUN authorization installed privileges; '
          'handing off to Core restart',
        );
        return false;
      case AuthorizeCode.none:
        authorizationNotifier.value = TunAuthorizationState.authorized;
        commonPrint.log(
          'TUN authorization found existing privileges; '
          'continuing with the current Core',
        );
        return true;
      case AuthorizeCode.error:
        commonPrint.log(
          'TUN authorization failed; setup will continue with TUN disabled',
          logLevel: LogLevel.warning,
        );
        return true;
    }
  }

  Future<_SetupTaskResult> _setupConfig({
    bool force = false,
    bool silence = false,
    Future<void> Function()? preloadInvoke,
    FutureOr Function()? onUpdated,
  }) async {
    var profile = ref.read(currentProfileProvider);
    final nextProfile = await profile?.checkAndUpdateAndCopy();
    if (nextProfile != null) {
      profile = nextProfile;
      ref.read(profilesProvider.notifier).put(nextProfile);
    }
    commonPrint.log('setup ===> ${profile?.realLabel}');
    final patchConfig = ref.read(patchClashConfigProvider);
    final shouldContinueSetup = await requestAdmin(patchConfig.tun.enable);
    if (!shouldContinueSetup) {
      commonPrint.log(
        'TUN profile setup handed off to Core restart after authorization',
      );
      return _SetupTaskResult.handoffToCoreRestart;
    }
    final effectiveTunEnable = _getEffectiveTunEnable(patchConfig.tun.enable);
    final authorizationState = ref.read(authorizedTunEnableProvider);
    commonPrint.log(
      'TUN profile decision requested=${patchConfig.tun.enable} '
      'authorization=${authorizationState.name} '
      'effective=$effectiveTunEnable',
      logLevel: patchConfig.tun.enable && !effectiveTunEnable
          ? LogLevel.warning
          : LogLevel.info,
    );
    final realPatchConfig = patchConfig.copyWith.tun(
      enable: effectiveTunEnable,
    );
    final setupState = await ref.read(setupStateProvider(profile?.id).future);
    final vm2 = await getProfile(
      setupState: setupState,
      patchConfig: realPatchConfig,
    );
    final yamlString = vm2.a;
    final yamlMd5 = vm2.b;
    if (yamlMd5 == globalState.lastConfigMd5 && force == false) {
      return _SetupTaskResult.completed;
    }
    if (system.isAndroid) {
      globalState.lastVpnState = ref.read(vpnStateProvider);
      final sharedState = ref.read(sharedStateProvider);
      await preferences.saveShareState(sharedState);
    }
    await globalState.loadingRun(
      () async {
        final configFilePath = await appPath.configFilePath;
        await File(configFilePath).safeWriteAsString(yamlString);
        final message = await coreController.setupConfig(
          params: _setupParams,
          preloadInvoke: preloadInvoke,
        );
        commonPrint.log(
          'Core profile setup response '
          'tunEffective=$effectiveTunEnable messageEmpty=${message.isEmpty}',
          logLevel: message.isEmpty ? LogLevel.info : LogLevel.warning,
        );
        if (message.isNotEmpty && !message.endsWith('is empty')) {
          throw message;
        }
        globalState.lastConfigMd5 = yamlMd5;
        ref.read(checkIpNumProvider.notifier).add();
        await onUpdated?.call();
      },
      silence: true,
      tag: !silence ? LoadingTag.proxies : null,
    );
    return _SetupTaskResult.completed;
  }
}
