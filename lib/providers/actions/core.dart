part of '../action.dart';

String _coreDiagnosticError(Object error) {
  if (error is! DesktopCoreFailure) {
    return error.toString();
  }
  return 'DesktopCoreFailure(code=${error.code}, phase=${error.phase.name}, '
      'revision=${error.revision}, owner=${error.owner?.name}, '
      'pid=${error.pid}, generation=${error.connectionGeneration}, '
      'cause=${error.cause})';
}

@Riverpod(keepAlive: true)
class CoreAction extends _$CoreAction {
  int _requestedRestartRevision = 0;
  Future<void>? _restartOperation;

  @override
  void build() {}

  Future<void> initCore() async {
    final isInit = await coreController.isInit;

    final version = ref.read(versionProvider);
    if (!isInit) {
      final res = await coreController.init(version);
      commonPrint.log('init result: $res');
    } else {
      await ref.read(proxiesActionProvider.notifier).updateGroups();
    }
  }

  Future<void> startCore() async {
    ref.read(coreStatusProvider.notifier).value = CoreStatus.connecting;
    commonPrint.log('Core start requested');
    try {
      final result = await coreController.start();
      commonPrint.log(
        'Core start completed revision=${result.revision} '
        'outcome=${result.outcome.name} '
        'owner=${result.session?.owner.name} pid=${result.session?.pid}',
      );
      ref.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      await initCore();
    } catch (error) {
      commonPrint.log(
        'Core start failed: ${_coreDiagnosticError(error)}',
        logLevel: LogLevel.error,
      );
      ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
      globalState.showNotifier(error.toString());
    }
  }

  @protected
  Future<CoreLifecycleResult> restartLifecycle() {
    return coreController.restart();
  }

  Future<void> restartCore() {
    _requestedRestartRevision++;
    final activeOperation = _restartOperation;
    if (activeOperation != null) {
      return activeOperation;
    }

    final operation = _runRestartWorker();
    _restartOperation = operation;
    return operation;
  }

  Future<void> _runRestartWorker() async {
    try {
      ref.read(coreStatusProvider.notifier).value = CoreStatus.connecting;
      commonPrint.log(
        'Core restart worker started requestedRevision='
        '$_requestedRestartRevision',
      );
      final result = await restartLifecycle();
      commonPrint.log(
        'Core restart lifecycle completed revision=${result.revision} '
        'outcome=${result.outcome.name} '
        'owner=${result.session?.owner.name} pid=${result.session?.pid}',
      );
      ref.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      await initCore();

      var appliedRevision = 0;
      while (appliedRevision < _requestedRestartRevision) {
        final revision = _requestedRestartRevision;
        if (ref.read(isStartProvider)) {
          await ref
              .read(setupActionProvider.notifier)
              .setRunning(true, initialize: true);
        } else {
          await ref
              .read(setupActionProvider.notifier)
              .applyProfile(force: true);
        }
        appliedRevision = revision;
        commonPrint.log(
          'Core restart reapplied state requestedRevision=$revision '
          'running=${ref.read(isStartProvider)}',
        );
      }
    } catch (error) {
      commonPrint.log(
        'Core restart worker failed requestedRevision='
        '$_requestedRestartRevision: ${_coreDiagnosticError(error)}',
        logLevel: LogLevel.error,
      );
      ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
      rethrow;
    } finally {
      _restartOperation = null;
    }
  }
}
