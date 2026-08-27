import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';

import 'model.dart';

typedef CoreProcessStarter =
    Future<Process> Function(String executable, List<String> arguments);
typedef CoreDiagnosticLogger = void Function(String message, LogLevel logLevel);

void coreDiagnosticLog(String message, LogLevel logLevel) {
  commonPrint.log(message, logLevel: logLevel);
}

abstract interface class CoreProcessLauncher {
  Future<CoreProcessLease> start({
    required String sessionId,
    required String address,
  });
}

abstract interface class DesktopCoreLauncherResolver {
  Future<CoreProcessLauncher> resolve();
}

final class DirectCoreLauncher implements CoreProcessLauncher {
  final CoreProcessStarter _startProcess;
  final CoreDiagnosticLogger _diagnosticLog;
  final String corePath;

  DirectCoreLauncher({
    CoreProcessStarter? startProcess,
    CoreDiagnosticLogger? diagnosticLog,
    String? corePath,
  }) : _startProcess = startProcess ?? Process.start,
       _diagnosticLog = diagnosticLog ?? coreDiagnosticLog,
       corePath = corePath ?? appPath.corePath;

  @override
  Future<CoreProcessLease> start({
    required String sessionId,
    required String address,
  }) async {
    _diagnosticLog('direct Core launch requested', LogLevel.warning);
    try {
      final process = await _startProcess(corePath, [address]);
      _diagnosticLog(
        'direct Core process started pid=${process.pid}',
        LogLevel.warning,
      );
      process.stdout.listen((_) {});
      process.stderr.listen((data) {
        final error = utf8.decode(data);
        if (error.isNotEmpty) {
          _diagnosticLog(
            'direct Core stderr pid=${process.pid}: $error',
            LogLevel.warning,
          );
        }
      });
      return DirectCoreLease(
        sessionId: sessionId,
        process: process,
        diagnosticLog: _diagnosticLog,
      );
    } catch (error) {
      _diagnosticLog('direct Core launch failed: $error', LogLevel.error);
      rethrow;
    }
  }
}

final class DirectCoreLease implements CoreProcessLease {
  @override
  final String sessionId;

  final Process _process;
  final CoreDiagnosticLogger _diagnosticLog;
  Future<CoreProcessStopResult>? _stopOperation;

  DirectCoreLease({
    required this.sessionId,
    required Process process,
    CoreDiagnosticLogger? diagnosticLog,
  }) : _process = process,
       _diagnosticLog = diagnosticLog ?? coreDiagnosticLog;

  @override
  CoreProcessOwner get owner => CoreProcessOwner.direct;

  @override
  int get pid => _process.pid;

  @override
  Future<CoreProcessStopResult> stop(Duration timeout) {
    final stopOperation = _stopOperation;
    if (stopOperation != null) {
      return stopOperation;
    }
    final nextOperation = _stop(timeout).then((result) {
      if (!result.exitConfirmed) {
        _stopOperation = null;
      }
      return result;
    });
    _stopOperation = nextOperation;
    return nextOperation;
  }

  Future<CoreProcessStopResult> _stop(Duration timeout) async {
    final stopped = _process.kill();
    _diagnosticLog(
      'direct Core stop requested pid=$pid signalSent=$stopped '
      'timeoutMs=${timeout.inMilliseconds}',
      LogLevel.info,
    );
    try {
      await _process.exitCode.timeout(timeout);
      _diagnosticLog('direct Core exit confirmed pid=$pid', LogLevel.info);
      return CoreProcessStopResult(stopped: stopped, exitConfirmed: true);
    } on TimeoutException {
      _diagnosticLog(
        'direct Core exit unconfirmed pid=$pid after '
        '${timeout.inMilliseconds}ms',
        LogLevel.warning,
      );
      return CoreProcessStopResult(stopped: stopped, exitConfirmed: false);
    }
  }
}
