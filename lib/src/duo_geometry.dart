import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

/// How the iPhone Duo is folded.
enum DuoPosture {
  /// Folded: only the outer screen is in use.
  closed,

  /// Partially open, like a book.
  book,

  /// Open as far as the device allows: flat.
  open,

  /// Not a foldable, or no hinge information yet.
  unsupported,
}

/// Which screen shows the Flutter view.
enum DuoScreen {
  /// The outer screen, used when the device is closed.
  outer,

  /// The inner screen, which has the hinge.
  inner,

  /// Not known yet.
  unknown,
}

/// The display geometry of an iPhone Duo around the Flutter view.
///
/// Rectangles are in logical pixels, in the Flutter view's coordinate space:
/// the same space as `MediaQuery`.
@immutable
class DuoGeometry {
  /// Creates a geometry.
  const DuoGeometry({
    required this.posture,
    required this.screen,
    this.hingeAngle,
    this.hinge,
    this.cutouts = const [],
    this.statusColumns = const [],
    this.verticalBars = false,
    this.isSplitView = false,
  });

  /// How the device is folded.
  final DuoPosture posture;

  /// Hinge angle in degrees, from 0 (closed) to 180 (flat), or null when
  /// unknown.
  final double? hingeAngle;

  /// Which screen shows the Flutter view.
  final DuoScreen screen;

  /// The band to keep content out of around the fold, margins included, or
  /// null when the Flutter view is not on the inner screen.
  final Rect? hinge;

  /// Active camera areas.
  final List<Rect> cutouts;

  /// Active status bar areas: a vertical column when bars are vertical, a
  /// horizontal band otherwise.
  final List<Rect> statusColumns;

  /// Whether the system places its bars vertically, along one edge.
  final bool verticalBars;

  /// Whether the window is smaller than the screen.
  final bool isSplitView;

  @override
  bool operator ==(Object other) =>
      other is DuoGeometry &&
      other.posture == posture &&
      other.hingeAngle == hingeAngle &&
      other.screen == screen &&
      other.hinge == hinge &&
      listEquals(other.cutouts, cutouts) &&
      listEquals(other.statusColumns, statusColumns) &&
      other.verticalBars == verticalBars &&
      other.isSplitView == isSplitView;

  @override
  int get hashCode => Object.hash(
    posture,
    hingeAngle,
    screen,
    hinge,
    Object.hashAll(cutouts),
    Object.hashAll(statusColumns),
    verticalBars,
    isSplitView,
  );

  @override
  String toString() =>
      'DuoGeometry(posture: ${posture.name}, hingeAngle: $hingeAngle, '
      'screen: ${screen.name}, hinge: $hinge, cutouts: $cutouts, '
      'statusColumns: $statusColumns, verticalBars: $verticalBars, '
      'isSplitView: $isSplitView)';
}
