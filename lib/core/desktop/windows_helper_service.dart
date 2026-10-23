import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:fl_clash/common/constant.dart';
import 'package:win32/win32.dart' as win32;

enum WindowsHelperServiceState {
  notInstalled,
  starting,
  running,
  stopped,
  unknown,
}

Future<WindowsHelperServiceState> queryWindowsHelperServiceState() async {
  if (!Platform.isWindows) return WindowsHelperServiceState.unknown;
  try {
    return await Isolate.run(_queryServiceState);
  } catch (_) {
    return WindowsHelperServiceState.unknown;
  }
}

WindowsHelperServiceState _queryServiceState() {
  final manager = win32.OpenSCManager(
    null,
    null,
    win32.SC_MANAGER_CONNECT,
  ).value;
  if (!manager.isValid) return WindowsHelperServiceState.unknown;
  try {
    return using((arena) {
      final name = win32.PCWSTR(
        appHelperService.toNativeUtf16(allocator: arena),
      );
      final result = win32.OpenService(
        manager,
        name,
        win32.SERVICE_QUERY_STATUS,
      );
      final service = result.value;
      if (!service.isValid) {
        return result.error == win32.ERROR_SERVICE_DOES_NOT_EXIST
            ? WindowsHelperServiceState.notInstalled
            : WindowsHelperServiceState.unknown;
      }
      try {
        final status = arena<win32.SERVICE_STATUS_PROCESS>();
        final queried = win32.QueryServiceStatusEx(
          service,
          win32.SC_STATUS_PROCESS_INFO,
          status.cast(),
          sizeOf<win32.SERVICE_STATUS_PROCESS>(),
          arena<Uint32>(),
        );
        if (!queried.value) return WindowsHelperServiceState.unknown;
        return switch (status.ref.dwCurrentState) {
          win32.SERVICE_START_PENDING => WindowsHelperServiceState.starting,
          win32.SERVICE_RUNNING => WindowsHelperServiceState.running,
          win32.SERVICE_STOPPED => WindowsHelperServiceState.stopped,
          _ => WindowsHelperServiceState.unknown,
        };
      } finally {
        service.close();
      }
    });
  } finally {
    manager.close();
  }
}
