import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:duo_display/src/duo_geometry.dart';
import 'package:duo_display/src/messages.g.dart';

/// Tolerance, in points, when comparing native geometry.
const double _tolerance = 0.5;

/// Interprets a snapshot sent by the native observer.
///
/// Frames arrive in points, in the coordinate space of the native view that
/// hosts Flutter. On iOS one logical pixel is one point, and the observer
/// shares the Flutter view's bounds, so frames are already in Flutter's
/// logical-pixel, view-relative coordinates and are used as is.
DuoGeometry geometryFromMessage(DuoGeometryMessage message) {
  final division = message.regions
      .where((region) => region.kind == RegionKindMessage.division)
      .firstOrNull;
  final hasOcclusions = message.regions.any(
    (region) => region.kind == RegionKindMessage.occlusion,
  );

  final view = Rect.fromLTWH(
    0,
    0,
    message.viewSize.width,
    message.viewSize.height,
  );
  final cutouts = <Rect>[];
  final statusColumns = <Rect>[];
  for (final region in message.regions) {
    if (region.kind != RegionKindMessage.occlusion || !region.active) continue;
    final rect = _rect(region.frame);
    // UIKit gives no way to tell a camera from the status column: region
    // identifiers are opaque. On every captured pose and orientation, the
    // status column is anchored to an edge of the view (top right in
    // portrait, bottom right in landscape on the outer screen) while cameras
    // sit inside the panel, away from every edge.
    (_touchesEdge(rect, view) ? statusColumns : cutouts).add(rect);
  }

  final angle = message.hingeAngle;
  return DuoGeometry(
    posture: _posture(
      message.hingeStatus,
      division,
      hasOcclusions: hasOcclusions,
    ),
    hingeAngle: angle == null ? null : angle * 180 / math.pi,
    screen: _screen(
      message.hingeStatus,
      division,
      hasOcclusions: hasOcclusions,
    ),
    hinge: division == null ? null : _rect(division.frame),
    cutouts: List.unmodifiable(cutouts),
    statusColumns: List.unmodifiable(statusColumns),
    verticalBars: message.verticalBarEdge != VerticalBarEdgeMessage.unspecified,
    isSplitView: !_sameSize(message.windowSize, message.screenSize),
  );
}

/// The hinge status decides the posture. The division's `active` flag lags
/// it by seconds, and can stay false in a Book pose, so it only serves as a
/// fallback until UIKit delivers the first hinge state.
DuoPosture _posture(
  HingeStatusMessage? status,
  RegionMessage? division, {
  required bool hasOcclusions,
}) => switch (status) {
  HingeStatusMessage.closed => DuoPosture.closed,
  HingeStatusMessage.partiallyOpen => DuoPosture.book,
  HingeStatusMessage.fullyOpen => DuoPosture.open,
  HingeStatusMessage.unknown || null => switch (division) {
    RegionMessage(active: true) => DuoPosture.book,
    RegionMessage(active: false) => DuoPosture.open,
    null => hasOcclusions ? DuoPosture.closed : DuoPosture.unsupported,
  },
};

/// Only the inner screen has a division region, active or not.
DuoScreen _screen(
  HingeStatusMessage? status,
  RegionMessage? division, {
  required bool hasOcclusions,
}) {
  if (division != null) return DuoScreen.inner;
  if (hasOcclusions || status == HingeStatusMessage.closed) {
    return DuoScreen.outer;
  }
  return DuoScreen.unknown;
}

Rect _rect(RectMessage frame) =>
    Rect.fromLTWH(frame.x, frame.y, frame.width, frame.height);

bool _touchesEdge(Rect rect, Rect view) =>
    rect.left - view.left <= _tolerance ||
    rect.top - view.top <= _tolerance ||
    view.right - rect.right <= _tolerance ||
    view.bottom - rect.bottom <= _tolerance;

bool _sameSize(SizeMessage a, SizeMessage b) =>
    (a.width - b.width).abs() <= _tolerance &&
    (a.height - b.height).abs() <= _tolerance;
