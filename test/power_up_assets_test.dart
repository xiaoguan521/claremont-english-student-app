import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('power-up bundled assets stay available', () async {
    const assetPaths = [
      'assets/textbooks/power-up/page-4.png',
      'assets/textbooks/power-up/page-4.pdf',
      'assets/textbooks/power-up/page-6.png',
      'assets/textbooks/power-up/page-6.pdf',
      'assets/media/power-up/page-4-ex1.mp3',
      'assets/media/power-up/page-4-demo.mp4',
      'assets/media/power-up/page-6-ex1.mp3',
      'assets/media/power-up/page-6-demo.mp4',
    ];

    for (final assetPath in assetPaths) {
      final bytes = await rootBundle.load(assetPath);
      expect(
        bytes.lengthInBytes,
        greaterThan(0),
        reason: '$assetPath should be bundled into the Flutter app.',
      );
    }
  });
}
