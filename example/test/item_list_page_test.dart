import 'dart:ui';

import 'package:duo_display_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _bookHinge = DisplayFeature(
  bounds: Rect.fromLTWH(455.5, 0, 40, 669),
  type: DisplayFeatureType.hinge,
  state: DisplayFeatureState.postureHalfOpened,
);

void main() {
  testWidgets('in Book, tapping an item shows it in the other pane', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(951, 669)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(
          size: Size(951, 669),
          displayFeatures: [_bookHinge],
        ),
        child: ExampleApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Item 1'), findsNWidgets(2));

    await tester.tap(find.text('Item 5'));
    await tester.pumpAndSettle();

    // Once in the list, once as the detail's title.
    expect(find.text('Item 5'), findsNWidgets(2));
  });
}
