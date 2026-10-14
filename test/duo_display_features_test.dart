import 'dart:ui';

import 'package:duo_display/duo_display.dart';
import 'package:duo_display/src/duo_display_features.dart';
import 'package:duo_display/src/geometry_mapping.dart';
import 'package:duo_display/src/messages.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('book: a half-opened hinge', (tester) async {
    expect(await featuresSeen(tester, geometry: fixture('book')), const [
      DisplayFeature(
        bounds: _hingeLandscape,
        type: DisplayFeatureType.hinge,
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

  testWidgets('open: a flat hinge, and no cutout (inner camera inactive)', (
    tester,
  ) async {
    expect(await featuresSeen(tester, geometry: fixture('open')), const [
      DisplayFeature(
        bounds: _hingeLandscape,
        type: DisplayFeatureType.hinge,
        state: DisplayFeatureState.postureFlat,
      ),
    ]);
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

  testWidgets('a dialog opens on one side of the hinge', (tester) async {
    tester.view
      ..physicalSize = const Size(951, 669)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GeometryDisplayFeatures(
        geometry: Stream.value(fixture('book')),
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

    final dialog = tester.getRect(find.byType(AlertDialog));
    expect(dialog.right, lessThanOrEqualTo(_hingeLandscape.left));
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

    expect(seen.single.type, DisplayFeatureType.hinge);
    expect(seen.single.state, DisplayFeatureState.postureHalfOpened);
  });
}
