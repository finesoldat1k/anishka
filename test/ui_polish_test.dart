import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:anishka/core/theme/app_scroll_behavior.dart';
import 'package:anishka/ui/widgets/skeleton.dart';

void main() {
  testWidgets('skeleton highlight keeps moving', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: SkeletonBox(width: 120, height: 40)),
        ),
      ),
    );

    LinearGradient gradient() {
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(SkeletonBox),
          matching: find.byType(Container),
        ),
      );
      return (container.decoration! as BoxDecoration).gradient!
          as LinearGradient;
    }

    final first = gradient().begin;
    await tester.pump(const Duration(milliseconds: 360));
    final second = gradient().begin;

    expect(second, isNot(first));
  });

  testWidgets('app scroll behavior never inserts a scrollbar', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const AppScrollBehavior(),
        home: Scaffold(
          body: ListView.builder(
            itemCount: 80,
            itemBuilder: (context, index) =>
                SizedBox(height: 48, child: Text('$index')),
          ),
        ),
      ),
    );

    expect(find.byType(Scrollbar), findsNothing);
  });
}
