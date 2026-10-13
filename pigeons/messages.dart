// Pigeon schema for the iOS <-> Dart channel. Regenerate with:
//   dart run pigeon --input pigeons/messages.dart
//
// The native side sends raw UIKit data. Interpreting it (posture, camera vs
// status column, screen) happens in Dart, where it is unit tested against the
// probe fixtures.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartOptions: DartOptions(),
    swiftOut: 'ios/duo_display/Sources/duo_display/Messages.g.swift',
    swiftOptions: SwiftOptions(),
    dartPackageName: 'duo_display',
  ),
)
/// `UIView.ReservedRegion.Kind`.
enum RegionKindMessage {
  /// Where content should split in two: the hinge.
  division,

  /// Where an element covers the screen: a camera or the status column.
  occlusion,
}

/// `UIHinge.Status`.
enum HingeStatusMessage {
  /// The hinge status is unknown.
  unknown,

  /// The hinge is closed.
  closed,

  /// The hinge is partially open.
  partiallyOpen,

  /// The hinge is open as far as the device allows.
  fullyOpen,
}

/// `UIVerticalBarEdge`.
enum VerticalBarEdgeMessage {
  /// No vertical bar.
  unspecified,

  /// Vertical bar on the leading edge.
  leading,

  /// Vertical bar on the trailing edge.
  trailing,
}

/// A rectangle in points, in the coordinate space of the view hosting Flutter.
class RectMessage {
  /// Creates a rectangle.
  RectMessage({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Left edge.
  double x;

  /// Top edge.
  double y;

  /// Width.
  double width;

  /// Height.
  double height;
}

/// A size in points.
class SizeMessage {
  /// Creates a size.
  SizeMessage({required this.width, required this.height});

  /// Width.
  double width;

  /// Height.
  double height;
}

/// One `UIView.ReservedRegion`, queried with `.includeInactive`.
class RegionMessage {
  /// Creates a region.
  RegionMessage({
    required this.kind,
    required this.active,
    required this.frame,
  });

  /// Region kind.
  RegionKindMessage kind;

  /// `isActive`.
  bool active;

  /// Frame, margins included.
  RectMessage frame;
}

/// A settled snapshot of the display geometry around the Flutter view.
class DuoGeometryMessage {
  /// Creates a snapshot.
  DuoGeometryMessage({
    required this.viewSize,
    required this.windowSize,
    required this.screenSize,
    required this.verticalBarEdge,
    required this.regions,
    this.hingeStatus,
    this.hingeAngle,
  });

  /// Bounds of the view hosting Flutter content.
  SizeMessage viewSize;

  /// Bounds of its window.
  SizeMessage windowSize;

  /// Bounds of `windowScene.screen`, never `UIScreen.main`, which keeps
  /// reporting the outer screen when the inner one is in use.
  SizeMessage screenSize;

  /// Last `UIHingeInteraction` status, or null when no hinge state has been
  /// delivered (yet).
  HingeStatusMessage? hingeStatus;

  /// Last hinge angle, in radians.
  double? hingeAngle;

  /// `traitCollection.verticalBarEdge`.
  VerticalBarEdgeMessage verticalBarEdge;

  /// Division and occlusion regions, active or not.
  List<RegionMessage> regions;
}

/// Calls from Dart to iOS.
@HostApi()
abstract class DuoDisplayHostApi {
  /// Whether this device and OS expose foldable geometry (iOS 27.1+ on a
  /// foldable iPhone).
  bool isSupported();

  /// The last settled geometry, or null when unsupported or not known yet.
  DuoGeometryMessage? current();
}

/// Calls from iOS to Dart.
@FlutterApi()
// A one-method interface is what Pigeon expects for a single callback.
// ignore: one_member_abstracts
abstract class DuoDisplayFlutterApi {
  /// Sent each time the settled geometry changes.
  void onGeometryChanged(DuoGeometryMessage geometry);
}
