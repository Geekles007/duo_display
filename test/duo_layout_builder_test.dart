import 'dart:ui';

import 'package:duo_display/duo_display.dart';
import 'package:duo_display/src/duo_display_features.dart';
import 'package:duo_display/src/geometry_mapping.dart';
import 'package:duo_display/src/messages.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/probe_fixture.dart';

List<DisplayFeature> features(String fixture) => displayFeaturesOf(
  geometryFromMessage(probeFixture(fixture)),
  includeCutouts: true,
);

const _landscape = Size(951, 669);
const _portrait = Size(669, 951);
const _portraitBookHinge = DisplayFeature(
  bounds: Rect.fromLTWH(0, 455.5, 669, 40),
  type: DisplayFeatureType.hinge,
  state: DisplayFeatureState.postureHalfOpened,
);

const _firstKey = Key('first');
const _secondKey = Key('second');

/// Counts how many times it is mounted.
class _CountsMounts extends StatefulWidget {
  const _CountsMounts(this.onMount);

  final VoidCallback onMount;

  @override
  State<_CountsMounts> createState() => _CountsMountsState();
}

class _CountsMountsState extends State<_CountsMounts> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  void setView(WidgetTester tester, Size size) {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// A [DuoLayoutBuilder] at the root, under [displayFeatures].
  Widget atRoot({
    required Size size,
    required List<DisplayFeature> displayFeatures,
    TextDirection textDirection = TextDirection.ltr,
    bool splitWhenFlat = false,
    void Function(DuoLayout layout)? onLayout,
  }) => MediaQuery(
    data: MediaQueryData(size: size, displayFeatures: displayFeatures),
    child: Directionality(
      textDirection: textDirection,
      child: DuoLayoutBuilder(
        splitWhenFlat: splitWhenFlat,
        builder: (context, layout) {
          onLayout?.call(layout);
          return layout.place(
            first: Container(key: _firstKey),
            second: Container(key: _secondKey),
          );
        },
      ),
    ),
  );

  testWidgets('place puts the panes on either side of the hinge', (
    tester,
  ) async {
    setView(tester, _landscape);
    await tester.pumpWidget(
      atRoot(size: _landscape, displayFeatures: features('book')),
    );

    expect(
      tester.getRect(find.byKey(_firstKey)),
      const Rect.fromLTRB(0, 0, 455.5, 669),
    );
    expect(
      tester.getRect(find.byKey(_secondKey)),
      const Rect.fromLTRB(495.5, 0, 951, 669),
    );
  });

  testWidgets('not split: only first is built', (tester) async {
    setView(tester, _landscape);
    var secondBuilds = 0;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: _landscape),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: DuoLayoutBuilder(
            builder: (context, layout) => layout.place(
              first: Container(key: _firstKey),
              second: Builder(
                builder: (context) {
                  secondBuilds++;
                  return Container(key: _secondKey);
                },
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getRect(find.byKey(_firstKey)),
      const Rect.fromLTWH(0, 0, 951, 669),
    );
    expect(find.byKey(_secondKey), findsNothing);
    expect(secondBuilds, 0);
  });

  testWidgets('corrects its position under an app bar', (tester) async {
    setView(tester, _portrait);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: _portrait,
          displayFeatures: [_portraitBookHinge],
        ),
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(),
            body: DuoLayoutBuilder(
              builder: (context, layout) => layout.place(
                first: Container(key: _firstKey),
                second: Container(key: _secondKey),
              ),
            ),
          ),
        ),
      ),
    );

    // The first frame assumes the builder sits at the top of the screen.
    expect(tester.getRect(find.byKey(_secondKey)).top, isNot(495.5));

    await tester.pump();

    expect(tester.getRect(find.byKey(_firstKey)).bottom, 455.5);
    expect(tester.getRect(find.byKey(_secondKey)).top, 495.5);
  });

  testWidgets('correct on the first frame at the origin', (tester) async {
    setView(tester, _landscape);
    await tester.pumpWidget(
      atRoot(size: _landscape, displayFeatures: features('book')),
    );

    expect(tester.getRect(find.byKey(_secondKey)).left, 495.5);
  });

  testWidgets('follows pose changes while mounted', (tester) async {
    setView(tester, _landscape);
    late DuoLayout last;
    Future<void> pose(String fixture) => tester.pumpWidget(
      atRoot(
        size: _landscape,
        displayFeatures: features(fixture),
        onLayout: (layout) => last = layout,
      ),
    );

    await pose('book');
    expect(last.isSplit, isTrue);

    await pose('open');
    expect(last.isSplit, isFalse);
    expect(find.byKey(_secondKey), findsNothing);

    await pose('closed');
    expect(last.isSplit, isFalse);
  });

  testWidgets('splitWhenFlat toggles at runtime', (tester) async {
    setView(tester, _landscape);
    Future<void> split({required bool whenFlat}) => tester.pumpWidget(
      atRoot(
        size: _landscape,
        displayFeatures: features('open'),
        splitWhenFlat: whenFlat,
      ),
    );

    await split(whenFlat: false);
    expect(find.byKey(_secondKey), findsNothing);

    await split(whenFlat: true);
    expect(tester.getRect(find.byKey(_secondKey)).left, 495.5);

    await split(whenFlat: false);
    expect(find.byKey(_secondKey), findsNothing);
  });

  testWidgets('swaps panes when the text direction flips', (tester) async {
    setView(tester, _landscape);
    await tester.pumpWidget(
      atRoot(size: _landscape, displayFeatures: features('book')),
    );
    expect(tester.getRect(find.byKey(_firstKey)).left, 0);

    await tester.pumpWidget(
      atRoot(
        size: _landscape,
        displayFeatures: features('book'),
        textDirection: TextDirection.rtl,
      ),
    );
    expect(tester.getRect(find.byKey(_firstKey)).left, 495.5);
  });

  testWidgets('restacks when the view rotates', (tester) async {
    setView(tester, _landscape);
    await tester.pumpWidget(
      atRoot(size: _landscape, displayFeatures: features('book')),
    );

    setView(tester, _portrait);
    await tester.pumpWidget(
      atRoot(size: _portrait, displayFeatures: const [_portraitBookHinge]),
    );

    expect(
      tester.getRect(find.byKey(_firstKey)),
      const Rect.fromLTRB(0, 0, 669, 455.5),
    );
  });

  testWidgets('with DuoDisplayFeatures above, splits from the host geometry', (
    tester,
  ) async {
    setView(tester, _landscape);
    const channel = 'dev.flutter.pigeon.duo_display.DuoDisplayHostApi.current';
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      channel,
      (_) async => DuoDisplayHostApi.pigeonChannelCodec.encodeMessage(
        <Object?>[probeFixture('book')],
      ),
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        channel,
        null,
      ),
    );

    await tester.pumpWidget(
      DuoDisplayFeatures(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: DuoLayoutBuilder(
            builder: (context, layout) => layout.place(
              first: Container(key: _firstKey),
              second: Container(key: _secondKey),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byKey(_secondKey)).left, 495.5);
  });

  testWidgets('first keeps its state when the split changes', (tester) async {
    setView(tester, _landscape);
    var mounts = 0;
    Widget pose(String fixture) => MediaQuery(
      data: MediaQueryData(
        size: _landscape,
        displayFeatures: features(fixture),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: DuoLayoutBuilder(
          builder: (context, layout) => layout.place(
            first: _CountsMounts(() => mounts++),
            second: const SizedBox(),
          ),
        ),
      ),
    );

    await tester.pumpWidget(pose('book'));
    await tester.pumpWidget(pose('open'));
    await tester.pumpWidget(pose('book'));

    expect(mounts, 1);
  });
}
