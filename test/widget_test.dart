import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_starter/features/home/presentation/pages/home_page.dart';

void main() {
  testWidgets('tablet home page renders student learning sections', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: HomePage())),
    );

    await tester.pumpAndSettle();

    expect(find.text('今日任务'), findsWidgets);
    expect(find.text('老师反馈'), findsWidgets);
    expect(find.text('我的学校'), findsOneWidget);
    expect(find.text('开始学习'), findsOneWidget);
  });
}
