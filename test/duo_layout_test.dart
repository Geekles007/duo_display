import 'dart:ui';

import 'package:duo_display/src/duo_display_features.dart';
import 'package:duo_display/src/duo_layout_builder.dart';
import 'package:duo_display/src/geometry_mapping.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/probe_fixture.dart';

List<DisplayFeature> features(String fixture) => displayFeaturesOf(
  geometryFromMessage(probeFixture(fixture)),
  includeCutouts: true,
);

DuoLayout compute(
  List<DisplayFeature> displayFeatures, {
  Rect area = const Rect.fromLTWH(0, 0, 951, 669),
  TextDirection textDirection = TextDirection.ltr,
  bool splitWhenFlat = false,
}) => computeDuoLayout(
  displayFeatures: displayFeatures,
  area: area,
  textDirection: textDirection,
  splitWhenFlat: splitWhenFlat,
);

const _portrait = Rect.fromLTWH(0, 0, 669, 951);

void main() {
  test('book splits side by side around the measured hinge', () {
    final layout = compute(features('book'));

    expect(layout.isSplit, isTrue);
    expect(layout.axis, Axis.horizontal);
    expect(layout.first, const Rect.fromLTRB(0, 0, 455.5, 669));
    expect(layout.second, const Rect.fromLTRB(495.5, 0, 951, 669));
    expect(layout.hinge, const Rect.fromLTRB(455.5, 0, 495.5, 669));
  });

  test('book with a lagging division still splits', () {
    expect(compute(features('book_division_inactive')).isSplit, isTrue);
  });

  test('flat does not split by default', () {
    final layout = compute(features('open'));

    expect(layout.isSplit, isFalse);
    expect(layout.axis, isNull);
    expect(layout.second, isNull);
    expect(layout.hinge, isNull);
    expect(layout.first, const Rect.fromLTWH(0, 0, 951, 669));
  });

  test('flat splits with splitWhenFlat', () {
    final book = compute(features('book'));
    final flat = compute(features('open'), splitWhenFlat: true);

    expect(flat.first, book.first);
    expect(flat.second, book.second);
    expect(flat.hinge, book.hinge);
  });

  test('flat portrait stacks with splitWhenFlat', () {
    final layout = compute(
      features('open_rotated'),
      area: _portrait,
      splitWhenFlat: true,
    );

    expect(layout.axis, Axis.vertical);
    expect(layout.first, const Rect.fromLTRB(0, 0, 669, 455.5));
    expect(layout.second, const Rect.fromLTRB(0, 495.5, 669, 951));
  });

  test('closed does not split and ignores the camera cutout', () {
    final layout = compute(
      features('closed'),
      area: const Rect.fromLTWH(0, 0, 466, 678),
    );

    expect(layout.isSplit, isFalse);
  });

  test('right-to-left swaps side by side panes', () {
    final layout = compute(
      features('book'),
      textDirection: TextDirection.rtl,
    );

    expect(layout.first, const Rect.fromLTRB(495.5, 0, 951, 669));
    expect(layout.second, const Rect.fromLTRB(0, 0, 455.5, 669));
  });

  test('right-to-left keeps stacked panes top first', () {
    DuoLayout stacked(TextDirection direction) => compute(
      features('open_rotated'),
      area: _portrait,
      textDirection: direction,
      splitWhenFlat: true,
    );
    final ltr = stacked(TextDirection.ltr);
    final rtl = stacked(TextDirection.rtl);

    expect(rtl.first, ltr.first);
    expect(rtl.second, ltr.second);
  });

  test('coordinates are relative to the area', () {
    final layout = compute(
      features('book'),
      area: const Rect.fromLTWH(0, 56, 951, 613),
    );

    expect(layout.first, const Rect.fromLTRB(0, 0, 455.5, 613));
    expect(layout.hinge, const Rect.fromLTRB(455.5, 0, 495.5, 613));
  });

  test('a hinge outside the area does not split', () {
    final layout = compute(
      features('book'),
      area: const Rect.fromLTWH(0, 0, 455.5, 669),
    );

    expect(layout.isSplit, isFalse);
  });

  test('an unknown state does not split', () {
    final layout = compute(const [
      DisplayFeature(
        bounds: Rect.fromLTWH(455.5, 0, 40, 669),
        type: DisplayFeatureType.hinge,
        state: DisplayFeatureState.unknown,
      ),
    ]);

    expect(layout.isSplit, isFalse);
  });

  test('an Android zero-width fold splits side by side', () {
    final layout = compute(const [
      DisplayFeature(
        bounds: Rect.fromLTWH(475, 0, 0, 669),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureHalfOpened,
      ),
    ]);

    expect(layout.first, const Rect.fromLTRB(0, 0, 475, 669));
    expect(layout.second, const Rect.fromLTRB(475, 0, 951, 669));
    expect(layout.hinge?.width, 0);
  });

  test('a zero-size feature is ignored', () {
    final layout = compute(const [
      DisplayFeature(
        bounds: Rect.fromLTWH(475, 300, 0, 0),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureHalfOpened,
      ),
    ]);

    expect(layout.isSplit, isFalse);
  });

  test('an unknown feature type is ignored', () {
    final layout = compute(const [
      DisplayFeature(
        bounds: Rect.fromLTWH(455.5, 0, 40, 669),
        type: DisplayFeatureType.unknown,
        state: DisplayFeatureState.postureHalfOpened,
      ),
    ]);

    expect(layout.isSplit, isFalse);
  });

  test('a cutout never splits, even across the whole area', () {
    // Flutter only allows the unknown state on cutouts.
    final layout = compute(
      const [
        DisplayFeature(
          bounds: Rect.fromLTWH(455.5, 0, 40, 669),
          type: DisplayFeatureType.cutout,
          state: DisplayFeatureState.unknown,
        ),
      ],
      splitWhenFlat: true,
    );

    expect(layout.isSplit, isFalse);
  });

  test('the first qualifying feature wins', () {
    final layout = compute([
      const DisplayFeature(
        bounds: Rect.fromLTWH(300, 0, 0, 669),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureHalfOpened,
      ),
      ...features('book'),
    ]);

    expect(layout.first, const Rect.fromLTRB(0, 0, 300, 669));
  });

  test('unbounded constraints do not split', () {
    final layout = compute(
      features('book'),
      area: const Rect.fromLTWH(0, 0, 951, double.infinity),
    );

    expect(layout.isSplit, isFalse);
    expect(layout.first.height, double.infinity);
  });

  test('equal layouts are equal', () {
    final a = compute(features('book'));
    final b = compute(features('book'));

    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
