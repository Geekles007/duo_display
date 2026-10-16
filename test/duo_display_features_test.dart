import 'dart:async';
import 'dart:ui';

import 'package:duo_display/duo_display.dart';
import 'package:duo_display/src/duo_display_features.dart';
import 'package:duo_display/src/geometry_mapping.dart';
import 'package:duo_display/src/messages.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/counts_mounts.dart';
import 'helpers/probe_fixture.dart';

DuoGeometry fixture(String name) => geometryFromMessage(probeFixture(name));

const _hingeLandscape = Rect.fromLTWH(455.5, 0, 40, 669);

void main() {
  /// Pumps a subtree under [GeometryDisplayFeatures] fed with [geometry] and
  /// returns the display features it sees.
  Future<List<DisplayFeature>> featuresSeen(
    WidgetTester tester, {
    DuoGeometry? geometry,
    bool includeCutouts = true,
    List<DisplayFeature> existing = const [],
  }) async {
    var seen = <DisplayFeature>[];
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: const Size(951, 669),
          displayFeatures: existing,
        ),
        child: GeometryDisplayFeatures(
          geometry: geometry == null
              ? const Stream.empty()
              : Stream.value(geometry),
          includeCutouts: includeCutouts,
          child: Builder(
            builder: (context) {
              seen = MediaQuery.displayFeaturesOf(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    return seen;
  }

  testWidgets('book: a half-opened fold', (tester) async {
    expect(await featuresSeen(tester, geometry: fixture('book')), const [
      DisplayFeature(
        bounds: _hingeLandscape,
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureHalfOpened,
      ),
    ]);
  });

  testWidgets('book with a lagging division: still half-opened', (
    tester,
  ) async {
    final features = await featuresSeen(
      tester,
      geometry: fixture('book_division_inactive'),
    );
    expect(features.single.state, DisplayFeatureState.postureHalfOpened);
  });

  testWidgets('open: nothing while flat, and no cutout (inner camera '
      'inactive)', (tester) async {
    expect(await featuresSeen(tester, geometry: fixture('open')), isEmpty);
    expect(
      await featuresSeen(tester, geometry: fixture('open_rotated')),
      isEmpty,
    );
  });

  testWidgets('the flat fold only reaches FlatFoldScope', (tester) async {
    final geometry = StreamController<DuoGeometry>();
    addTearDown(geometry.close);
    DisplayFeature? flatFold;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(951, 669)),
        child: GeometryDisplayFeatures(
          geometry: geometry.stream,
          includeCutouts: true,
          child: Builder(
            builder: (context) {
              flatFold = FlatFoldScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    for (final (pose, expected) in [
      (
        'open',
        const DisplayFeature(
          bounds: _hingeLandscape,
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureFlat,
        ),
      ),
      ('book', null),
      ('closed', null),
    ]) {
      geometry.add(fixture(pose));
      await tester.pump();
      await tester.pump();
      expect(flatFold, expected, reason: pose);
    }
  });

  testWidgets('closed: the outer camera as a cutout, no hinge', (
    tester,
  ) async {
    expect(await featuresSeen(tester, geometry: fixture('closed')), const [
      DisplayFeature(
        bounds: Rect.fromLTWH(399.6666666666667, 29.333333333333332, 37, 37),
        type: DisplayFeatureType.cutout,
        state: DisplayFeatureState.unknown,
      ),
    ]);
  });

  testWidgets('includeCutouts: false leaves the camera out', (tester) async {
    final features = await featuresSeen(
      tester,
      geometry: fixture('closed'),
      includeCutouts: false,
    );
    expect(features, isEmpty);
  });

  testWidgets('display features from the engine are kept as is', (
    tester,
  ) async {
    const engine = DisplayFeature(
      bounds: Rect.fromLTWH(470, 0, 0, 669),
      type: DisplayFeatureType.fold,
      state: DisplayFeatureState.postureFlat,
    );
    final features = await featuresSeen(
      tester,
      geometry: fixture('book'),
      existing: const [engine],
    );
    expect(features, const [engine]);
  });

  testWidgets('no geometry: nothing is added', (tester) async {
    expect(await featuresSeen(tester), isEmpty);
  });

  /// Opens an [AlertDialog] in a landscape inner screen posed as [pose] and
  /// returns where it lands.
  Future<Rect> dialogRect(WidgetTester tester, String pose) async {
    tester.view
      ..physicalSize = const Size(951, 669)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GeometryDisplayFeatures(
        geometry: Stream.value(fixture(pose)),
        includeCutouts: true,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const AlertDialog(title: Text('Hello')),
                ),
                child: const Text('Open dialog'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    return tester.getRect(find.byType(AlertDialog));
  }

  testWidgets('book: a dialog opens on one side of the fold', (tester) async {
    final dialog = await dialogRect(tester, 'book');
    expect(dialog.right, lessThanOrEqualTo(_hingeLandscape.left));
  });

  testWidgets('flat: a dialog can span the screen', (tester) async {
    final dialog = await dialogRect(tester, 'open');
    expect(dialog.left, lessThan(_hingeLandscape.left));
    expect(dialog.right, greaterThan(_hingeLandscape.right));
  });

  testWidgets('DuoDisplayFeatures reads the geometry from the host', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.duo_display.DuoDisplayHostApi.current',
      (_) async => DuoDisplayHostApi.pigeonChannelCodec.encodeMessage(
        <Object?>[probeFixture('book')],
      ),
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'dev.flutter.pigeon.duo_display.DuoDisplayHostApi.current',
        null,
      ),
    );

    var seen = <DisplayFeature>[];
    await tester.pumpWidget(
      DuoDisplayFeatures(
        child: Builder(
          builder: (context) {
            seen = MediaQuery.displayFeaturesOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(seen.single.type, DisplayFeatureType.fold);
    expect(seen.single.state, DisplayFeatureState.postureHalfOpened);
  });

  testWidgets('the app keeps its state as display features come and go', (
    tester,
  ) async {
    final geometry = StreamController<DuoGeometry>();
    addTearDown(geometry.close);
    var mounts = 0;
    var seen = <DisplayFeature>[];
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(951, 669)),
        child: GeometryDisplayFeatures(
          geometry: geometry.stream,
          includeCutouts: false,
          child: Builder(
            builder: (context) {
              seen = MediaQuery.displayFeaturesOf(context);
              return CountsMounts(() => mounts++);
            },
          ),
        ),
      ),
    );

    // The first geometry adds a hinge; closed without cutouts has no
    // display feature at all; Book adds the hinge back.
    for (final (pose, featureCount) in [
      ('book', 1),
      ('closed', 0),
      ('book', 1),
    ]) {
      geometry.add(fixture(pose));
      // The event is delivered in a microtask, then rebuilt on next frame.
      await tester.pump();
      await tester.pump();
      expect(seen, hasLength(featureCount), reason: pose);
    }

    expect(mounts, 1);
  });
}
