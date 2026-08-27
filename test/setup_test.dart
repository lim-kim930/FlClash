import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import '../setup.dart' as setup;

void main() {
  group('setup.dart', () {
    test('parses -v as verbose mode', () {
      final results = setup.createSetupArgParser().parse(['android', '-v']);

      expect(results['verbose'], isTrue);
      expect(results.rest, ['android']);
    });

    test('accepts dev application environment', () {
      final results = setup.createSetupArgParser().parse([
        'android',
        '--env',
        'dev',
      ]);

      expect(results['env'], 'dev');
    });

    test('Flutter build environment does not depend on Core SHA256', () {
      expect(setup.createBuildEnvironment('dev'), {'APP_ENV': 'dev'});
    });

    test('omits verbose from flutter build args by default', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'android',
        verbose: false,
      );

      expect(args, ['dart-define-from-file=env.json', 'split-per-abi']);
    });

    test('adds verbose to flutter build args with -v', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'android',
        verbose: true,
      );

      expect(args, [
        'verbose',
        'dart-define-from-file=env.json',
        'split-per-abi',
      ]);
    });

    test(
      'Windows packaging uses the built-in setup icon and app icon layers',
      () {
        final config = File(
          'windows/packaging/exe/make_config.yaml',
        ).readAsStringSync();

        expect(config, isNot(contains('setup_icon_file:')));
        expect(
          config,
          contains(r'file: ..\windows\packaging\exe\ChineseSimplified.isl'),
        );

        final iconBytes = File(
          'windows/runner/resources/app_icon.ico',
        ).readAsBytesSync();
        final iconData = ByteData.sublistView(iconBytes);
        final iconCount = iconData.getUint16(4, Endian.little);
        final iconSizes = <int>{};
        for (var index = 0; index < iconCount; index++) {
          final entryOffset = 6 + index * 16;
          final width = iconBytes[entryOffset];
          iconSizes.add(width == 0 ? 256 : width);
          final imageOffset = iconData.getUint32(
            entryOffset + 12,
            Endian.little,
          );
          expect(iconData.getUint32(imageOffset, Endian.little), 40);
        }

        expect(iconSizes, containsAll(<int>{16, 32, 48, 64, 256}));
      },
    );
  });
}
