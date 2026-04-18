import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_starter/features/home/presentation/pages/home_page.dart';

void main() {
  testWidgets('tablet home page renders key management sections', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: HomePage())),
    );

    await tester.pumpAndSettle();

    expect(find.text('管理工作台'), findsOneWidget);
    expect(find.text('个人中心'), findsOneWidget);
    expect(find.text('数据中心'), findsOneWidget);
    expect(find.text('课程管理'), findsOneWidget);
  });
}
