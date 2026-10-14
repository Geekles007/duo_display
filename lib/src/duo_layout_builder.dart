import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// The panes on either side of the hinge, in logical pixels, relative to the
/// top left corner of the area being laid out.
@immutable
class DuoLayout {
  const DuoLayout._single(this.first)
    : axis = null,
      second = null,
      hinge = null;

  const DuoLayout._split({
    required Axis this.axis,
    required this.first,
    required Rect this.second,
    required Rect this.hinge,
  });

  /// [Axis.horizontal] when the panes sit side by side (vertical hinge),
  /// [Axis.vertical] when they are stacked (horizontal hinge), null when not
  /// split.
  final Axis? axis;

  /// The leading pane: left (right in right-to-left text) or top. When not
  /// split, the whole area.
  final Rect first;

  /// The trailing pane, or null when not split.
  final Rect? second;

  /// The hinge band, clipped to the area, or null when not split.
  final Rect? hinge;

  /// Whether the area is split in two around the hinge.
  bool get isSplit => second != null;

  @override
  bool operator ==(Object other) =>
      other is DuoLayout &&
      other.axis == axis &&
      other.first == first &&
      other.second == second &&
      other.hinge == hinge;

  @override
  int get hashCode => Object.hash(axis, first, second, hinge);

  @override
  String toString() =>
      'DuoLayout(axis: $axis, first: $first, second: $second, hinge: $hinge)';
}

/// Splits [area], the builder's rectangle in the Flutter view's coordinates,
/// around the first display feature that separates it.
///
/// A hinge or fold separates the area when it is half opened, or flat with
/// [splitWhenFlat], and when it crosses the area entirely while leaving room
/// on both sides. A feature taller than wide puts the panes side by side,
/// any other one stacks them.
@internal
DuoLayout computeDuoLayout({
  required List<DisplayFeature> displayFeatures,
  required Rect area,
  required TextDirection textDirection,
  required bool splitWhenFlat,
}) {
  final whole = Offset.zero & area.size;
  if (!area.isFinite) return DuoLayout._single(whole);

  for (final feature in displayFeatures) {
    final bounds = feature.bounds;
    if (!_separates(feature, splitWhenFlat: splitWhenFlat) ||
        (bounds.width == 0 && bounds.height == 0)) {
      continue;
    }
    final vertical = bounds.height > bounds.width;
    if (!_crosses(bounds, area, vertical: vertical)) continue;

    final local = bounds.shift(-area.topLeft);
    if (vertical) {
      final start = Rect.fromLTRB(0, 0, local.left, area.height);
      final end = Rect.fromLTRB(local.right, 0, area.width, area.height);
      final leftToRight = textDirection == TextDirection.ltr;
      return DuoLayout._split(
        axis: Axis.horizontal,
        first: leftToRight ? start : end,
        second: leftToRight ? end : start,
        hinge: Rect.fromLTRB(local.left, 0, local.right, area.height),
      );
    }
    return DuoLayout._split(
      axis: Axis.vertical,
      first: Rect.fromLTRB(0, 0, area.width, local.top),
      second: Rect.fromLTRB(0, local.bottom, area.width, area.height),
      hinge: Rect.fromLTRB(0, local.top, area.width, local.bottom),
    );
  }
  return DuoLayout._single(whole);
}

bool _separates(DisplayFeature feature, {required bool splitWhenFlat}) {
  if (feature.type != DisplayFeatureType.hinge &&
      feature.type != DisplayFeatureType.fold) {
    return false;
  }
  return switch (feature.state) {
    DisplayFeatureState.postureHalfOpened => true,
    DisplayFeatureState.postureFlat => splitWhenFlat,
    DisplayFeatureState.unknown => false,
  };
}

/// Whether [bounds] crosses [area] entirely along the hinge and leaves room
/// on both sides of it, as in `DisplayFeatureSubScreen`.
bool _crosses(Rect bounds, Rect area, {required bool vertical}) => vertical
    ? bounds.top <= area.top &&
          bounds.bottom >= area.bottom &&
          bounds.left > area.left &&
          bounds.right < area.right
    : bounds.left <= area.left &&
          bounds.right >= area.right &&
          bounds.top > area.top &&
          bounds.bottom < area.bottom;
